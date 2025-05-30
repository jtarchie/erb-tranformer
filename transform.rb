# frozen_string_literal: true

require 'parser/current'
require 'unparser'

class RenderTransformer < Parser::TreeRewriter
  def on_send(node)
    # Only transform if there's no receiver (bare render call)
    return unless node.children[0].nil?

    # Check if this is a render call
    return unless node.children[1] == :render

    # Skip if already using partial: syntax
    args = node.children[2..]
    return if args.any? { |arg| arg.type == :hash && has_partial_key?(arg) }

    # Only transform if first argument is a string or dynamic string (template path)
    first_arg = args.first
    return unless %i[str dstr].include?(first_arg&.type)

    template_path_node = first_arg

    # Build the new arguments
    new_args = build_new_args(template_path_node, args[1..])

    # Create new render call
    new_call = s(:send, nil, :render, *new_args)

    replace(node.loc.expression, Unparser.unparse(new_call))
  end

  private

  def has_partial_key?(hash_node)
    hash_node.children.any? do |pair|
      pair.type == :pair &&
        pair.children.first.type == :sym &&
        pair.children.first.children.first == :partial
    end
  end

  def build_new_args(template_path_node, remaining_args)
    args = []

    # Add partial: argument (preserve the original node type - str or dstr)
    partial_pair = s(:pair, s(:sym, :partial), template_path_node)

    # Handle remaining arguments
    if remaining_args.empty?
      # Just partial:
      args << s(:hash, partial_pair)
    elsif remaining_args.length == 1 && remaining_args.first.type == :hash
      # Existing hash - convert to locals:
      existing_hash = remaining_args.first
      locals_pair = s(:pair, s(:sym, :locals), existing_hash)
      args << s(:hash, partial_pair, locals_pair)
    else
      # Multiple arguments or non-hash - wrap in locals:
      locals_hash = s(:hash, *remaining_args)
      locals_pair = s(:pair, s(:sym, :locals), locals_hash)
      args << s(:hash, partial_pair, locals_pair)
    end

    args
  end

  def s(type, *children)
    Parser::AST::Node.new(type, children)
  end
end

class ERBTransformer
  def initialize
    @transformer = RenderTransformer.new
  end

  def transform_erb_file(file_path)
    puts "Processing: #{file_path}"
    content = File.read(file_path)
    transformed_content = transform_erb_content(content)

    if transformed_content != content
      puts "  ✓ Transformed: #{file_path}"
      File.write(file_path, transformed_content)
      true
    else
      puts "  - No changes: #{file_path}"
      false
    end
  end

  def transform_erb_content(content)
    # Find all ERB tags
    erb_tags_found = 0
    erb_tags_transformed = 0

    result = content.gsub(/<%=?\s*(.+?)\s*%>/m) do |match|
      erb_content = ::Regexp.last_match(1)
      erb_tags_found += 1

      # Skip if the content doesn't contain 'render'
      if erb_content.include?('render')
        begin
          # Parse the Ruby code inside ERB
          ast = Parser::CurrentRuby.parse erb_content

          # Transform render calls
          buffer = Parser::Source::Buffer.new('(erb)', source: erb_content)
          transformed = @transformer.rewrite(buffer, ast)

          if transformed != erb_content
            erb_tags_transformed += 1
            puts "    - Transformed ERB tag: #{erb_content.strip}"
          end

          # Preserve ERB tag style
          if match.start_with?('<%=')
            "<%= #{transformed} %>"
          else
            "<% #{transformed} %>"
          end
        rescue Parser::SyntaxError
          # If parsing fails, leave unchanged
          puts "    ! Syntax error in ERB tag, skipping: #{erb_content.strip}"
          match
        end
      else
        match
      end
    end

    puts "    Found #{erb_tags_found} ERB tags, transformed #{erb_tags_transformed}" if erb_tags_found.positive?

    result
  end
end

if __FILE__ == $PROGRAM_NAME
  # Usage
  if ARGV.empty?
    puts 'Usage: ruby transform_renders.rb <file_or_directory> [file_or_directory...]'
    exit 1
  end

  puts 'Starting ERB render transformation...'
  transformer = ERBTransformer.new
  files_changed = 0
  files_processed = 0

  ARGV.each do |path|
    puts "\nProcessing path: #{path}"

    if File.directory?(path)
      # Process all .erb files in directory recursively
      erb_files = Dir.glob(File.join(path, '**/*.erb'))
      puts "Found #{erb_files.length} ERB files in directory"

      erb_files.each do |file|
        files_processed += 1
        files_changed += 1 if transformer.transform_erb_file(file)
      end
    elsif File.exist?(path) && path.end_with?('.erb')
      files_processed += 1
      files_changed += 1 if transformer.transform_erb_file(path)
    else
      puts "Skipping: #{path} (not an ERB file or directory)"
    end
  end

  puts "\n#{'=' * 50}"
  puts 'Summary:'
  puts "Files processed: #{files_processed}"
  puts "Files changed: #{files_changed}"
  puts "Files unchanged: #{files_processed - files_changed}"
end
