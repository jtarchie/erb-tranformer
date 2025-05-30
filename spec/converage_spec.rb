# frozen_string_literal: true

require_relative '../transform'

RSpec.describe RenderTransformer do
  let(:transformer) { RenderTransformer.new }

  def transform_code(input)
    ast = Parser::CurrentRuby.parse(input)
    buffer = Parser::Source::Buffer.new('(test)', source: input)
    transformer.rewrite(buffer, ast)
  end

  describe '#on_send' do
    context 'when transforming simple render calls' do
      it 'transforms simple string template' do
        input = 'render "users/show"'
        expected = 'render({ partial: "users/show" })'
        expect(transform_code(input)).to eq(expected)
      end

      it 'transforms template with interpolation' do
        input = 'render "users/#{type}/show"'
        expected = 'render({ partial: "users/#{type}/show" })'
        expect(transform_code(input)).to eq(expected)
      end

      it 'transforms template with complex interpolation' do
        input = 'render "crowdfunding/projects/community/#{discussable_model.model_name.element}"'
        expected = 'render({ partial: "crowdfunding/projects/community/#{discussable_model.model_name.element}" })'
        expect(transform_code(input)).to eq(expected)
      end
    end

    context 'when transforming render calls with locals' do
      it 'transforms template with hash locals' do
        input = 'render "users/show", user: current_user, admin: true'
        expected = 'render({ partial: "users/show", locals: { user: current_user, admin: true } })'
        expect(transform_code(input)).to eq(expected)
      end

      it 'transforms template with single variable' do
        input = 'render "users/show", data'
        expected = 'render({ partial: "users/show", locals: { data } })'
        expect(transform_code(input)).to eq(expected)
      end

      it 'transforms template with interpolation and locals' do
        input = 'render "crowdfunding/projects/community/#{discussable_model.model_name.element}", model: discussable_model, reaction_counts: reaction_counts'
        expected = 'render({ partial: "crowdfunding/projects/community/#{discussable_model.model_name.element}", locals: { model: discussable_model, reaction_counts: } })'
        expect(transform_code(input)).to eq(expected)
      end

      it 'transforms template with existing hash' do
        input = 'render "users/show", {user: current_user}'
        expected = 'render({ partial: "users/show", locals: { user: current_user } })'
        expect(transform_code(input)).to eq(expected)
      end

      it 'transforms template with multiple variables' do
        input = 'render "posts/card", post, comments, author'
        expected = 'render({ partial: "posts/card", locals: { post, comments, author } })'
        expect(transform_code(input)).to eq(expected)
      end
    end

    context 'when render calls should not be transformed' do
      it 'does not change calls with partial key' do
        input = 'render partial: "users/show", locals: {user: current_user}'
        expect(transform_code(input)).to eq(input)
      end

      it 'does not change non-string first argument' do
        input = 'render user_template_path'
        expect(transform_code(input)).to eq(input)
      end

      it 'does not change calls with template key' do
        input = 'render template: "users/show", locals: {user: current_user}'
        expect(transform_code(input)).to eq(input)
      end

      it 'does not change calls with layout key' do
        input = 'render layout: "application", locals: {title: "Home"}'
        expect(transform_code(input)).to eq(input)
      end

      it 'does not change variable-based render calls' do
        input = 'render template_name, locals: data'
        expect(transform_code(input)).to eq(input)
      end
    end

    context 'when handling edge cases' do
      it 'transforms single quoted strings' do
        input = "render 'users/show'"
        expected = 'render({ partial: "users/show" })'
        expect(transform_code(input)).to eq(expected)
      end

      it 'transforms deeply nested templates' do
        input = 'render "admin/users/settings/notifications/email"'
        expected = 'render({ partial: "admin/users/settings/notifications/email" })'
        expect(transform_code(input)).to eq(expected)
      end

      it 'handles empty locals hash' do
        input = 'render "users/show", {}'
        expected = 'render({ partial: "users/show", locals: {} })'
        expect(transform_code(input)).to eq(expected)
      end

      it 'handles symbol keys in locals' do
        input = 'render "users/show", :user => current_user, :admin => true'
        expected = 'render({ partial: "users/show", locals: { user: current_user, admin: true } })'
        expect(transform_code(input)).to eq(expected)
      end

      it 'handles method calls as local values' do
        input = 'render "posts/summary", count: posts.count, author: post.author.name'
        expected = 'render({ partial: "posts/summary", locals: { count: posts.count, author: post.author.name } })'
        expect(transform_code(input)).to eq(expected)
      end
    end

    context 'when not render method calls' do
      it 'ignores other method calls' do
        input = 'puts "hello world"'
        expect(transform_code(input)).to eq(input)
      end

      it 'ignores render calls on other objects' do
        input = 'obj.render "template"'
        expect(transform_code(input)).to eq(input)
      end
    end
  end
end
