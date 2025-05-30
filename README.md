# ERB Render Transformer

## Description

A Ruby tool that automatically transforms Rails render calls in ERB templates to
use the modern `partial:` syntax. It converts old-style render calls like
`render "template_name"` to the newer `render partial: "template_name"` format,
while preserving locals and handling various edge cases.

## Usage

```bash
# Transform a single ERB file
ruby transform.rb path/to/template.erb

# Transform all ERB files in a directory
ruby transform.rb app/views/

# Transform multiple files/directories
ruby transform.rb app/views/ shared/components/ admin/templates/
```

The transformer will:

- Process all `.erb` files in the specified paths
- Transform render calls to use `partial:` syntax
- Wrap additional arguments in `locals:`
- Preserve interpolated strings and complex expressions
- Show a summary of files processed and changed
