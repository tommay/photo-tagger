require "nokogiri"
require "byebug"

class Xmp
  NAMESPACES = {
    "x" => "adobe:ns:meta/",
    "dc" => "http://purl.org/dc/elements/1.1/",
    "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    "xmp" => "http://ns.adobe.com/xap/1.0/",
  }.freeze

  MINIMAL = <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="XMP Core 4.4.0-Exiv2">
</x:xmpmeta>
EOF

  def initialize(string=MINIMAL)
    @xmp = Nokogiri::XML(string)
  end

  def get_tags
    @xmp.css("dc|subject rdf|li", NAMESPACES).map do |tag|
      tag.text
    end
  end

  def add_tag(tag)
    if !get_tags.include?(tag)
      xmpmeta = @xmp.at_css("x|xmpmeta", NAMESPACES)
      rdf = find_or_add_child(xmpmeta, "rdf:RDF")
      description = find_or_add_child(rdf, "rdf:Description")
      subject = find_or_add_child(description, "dc:subject")
      seq = find_or_add_child(subject, "rdf:Seq")
      li = Nokogiri::XML::Node.new("rdf:li", @xmp)
      li.content = tag
      seq.add_child(li)
    end
  end

  def set_rating(rating)
    xmpmeta = @xmp.at_css("x|xmpmeta", NAMESPACES)
    rdf = find_or_add_child(xmpmeta, "rdf:RDF")
    description = find_or_add_child(rdf, "rdf:Description")
    prefix = find_or_add_namespace(description, "xmp")
    description["#{prefix}:Rating"] = rating.to_s
  end

  def find_or_add_child(node, name)
    (prefix, name) = name.split(/:/, 2)
    child = node.at_css("#{prefix}|#{name}", NAMESPACES)
    if !child
      # Use an existing namespace if posssible.
      existing_ns = node.namespaces.invert[NAMESPACES[prefix]]
      if existing_ns
        prefix = existing_ns.sub(/^xmlns:/, "")
        child = Nokogiri::XML::Node.new("#{prefix}:#{name}", node.document)
      else
        child = Nokogiri::XML::Node.new("#{prefix}:#{name}", node.document)
        child.add_namespace(prefix, NAMESPACES[prefix])
      end
      node.add_child(child)
    end
    child
  end

  def find_or_add_namespace(node, prefix)
    # Use an existing namespace if posssible.
    existing_ns = node.namespaces.invert[NAMESPACES[prefix]]
    if existing_ns
      existing_ns.sub(/^xmlns:/, "")
    else
      node.add_namespace(prefix, NAMESPACES[prefix])
      prefix
    end
  end

  def to_s
    @xmp.to_xml
  end
end
