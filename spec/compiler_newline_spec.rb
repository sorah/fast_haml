require 'spec_helper'

class LineVerifier < StandardError
  def initialize
    super("raised at #{caller_locations(1, 1)[0].lineno}")
  end
end

module LineVerifierHelper
  extend RSpec::Matchers::DSL

  matcher :raised_at do |expected|
    match do |actual|
      actual == "raised at #{expected}"
    end
  end
end

RSpec.describe 'FastHaml::Compiler newline generation', type: :render do
  include LineVerifierHelper

  it do
    expect { render_string(<<HAML) }.to raise_error(LineVerifier, raised_at(3))
%div
  %span= 1
  %span>= raise LineVerifier
HAML
  end

  it do
    expect { render_string(<<HAML) }.to raise_error(LineVerifier, raised_at(2))
%img
%img{href: raise(LineVerifier)}>
%img
HAML
  end

  it do
    expect { render_string(<<'HAML') }.to raise_error(LineVerifier, raised_at(3))
%div
  %span hello
  %span #{raise LineVerifier}
  %span world
HAML
  end

  it do
    expect { render_string(<<HAML) }.to raise_error(LineVerifier, raised_at(2))

%div= raise LineVerifier
HAML
  end

  it 'keeps empty lines' do
    expect { render_string(<<HAML) }.to raise_error(LineVerifier, raised_at(4))
%div
  %span= 1

  %span= raise LineVerifier
HAML
  end

  it 'keeps leading empty lines' do
    expect { render_string(<<HAML) }.to raise_error(LineVerifier, raised_at(3))
%div

  %span= raise LineVerifier
HAML
  end

  it 'counts haml comments' do
    expect { render_string(<<HAML) }.to raise_error(LineVerifier, raised_at(3))
-# foo
   bar
%span= raise LineVerifier
HAML
  end
end
