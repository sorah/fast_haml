require 'spec_helper'

RSpec.describe 'Attributes rendering', type: :render do
  it 'parses attributes' do
    expect(render_string('%span{class: "x"} hello')).to eq(%Q{<span class="x">hello</span>\n})
  end

  it 'parses attributes' do
    expect(render_string('%span{class: "x", "old" => 2} hello')).to eq(%Q{<span class="x" old="2">hello</span>\n})
  end

  it 'renders dynamic attributes' do
    expect(render_string(%q|%span{class: "na#{'ni'}ka"} hello|)).to eq(%Q{<span class="nanika">hello</span>\n})
  end

  it 'escapes' do
    expect(render_string(%q|%span{class: "x\"y'z"} hello|)).to eq(%Q{<span class="x&quot;y&#39;z">hello</span>\n})
  end

  it 'renders only name if value is true' do
    expect(render_string(%q|%span{foo: true, bar: 1} hello|)).to eq(%Q{<span bar="1" foo>hello</span>\n})
  end

  it 'renders nested attributes' do
    expect(render_string(%q|%span{foo: {bar: 1+2}} hello|)).to eq(%Q|<span foo="{:bar=&gt;3}">hello</span>\n|)
  end

  it 'renders code attributes' do
    expect(render_string(<<HAML)).to eq(%Q|<span bar="{:hoge=&gt;:fuga}" foo="1">hello</span>\n|)
- attrs = { foo: 1, bar: { hoge: :fuga } }
%span{attrs} hello
HAML
  end

  it 'renders dstr attributes' do
    expect(render_string(<<HAML)).to eq(%Q|<span data="x{:foo=&gt;1}y">hello</span>\n|)
- data = { foo: 1 }
%span{data: "x\#{data}y"} hello
HAML
  end

  context 'with unmatched brace' do
    it 'raises error' do
      expect { render_string('%span{foo hello') }.to raise_error(FastHaml::Parser::SyntaxError)
    end
  end

  context 'with data attributes' do
    it 'renders nested attributes' do
      expect(render_string(%q|%span{data: {foo: 1, bar: 'baz', :hoge => :fuga}} hello|)).to eq(%Q{<span data-bar="baz" data-foo="1" data-hoge="fuga">hello</span>\n})
    end

    it 'renders nested dynamic attributes' do
      expect(render_string(%q|%span{data: {foo: "b#{'a'}r"}} hello|)).to eq(%Q{<span data-foo="bar">hello</span>\n})
    end

    it 'renders nested attributes' do
      expect(render_string(%q|%span{data: {foo: 1, bar: 2+3}} hello|)).to eq(%Q{<span data-bar="5" data-foo="1">hello</span>\n})
    end

    it 'renders nested code attributes' do
      expect(render_string(<<HAML)).to eq(%Q{<span data-bar="2" data-foo="1">hello</span>\n})
- data = { foo: 1, bar: 2 }
%span{data: data} hello
HAML
    end
  end
end