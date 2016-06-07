require "nokogiri"

class Xmp
  NAMESPACES = {
    "dc" => "http://purl.org/dc/elements/1.1/",
    "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
  }.freeze

  def initialize(string)
    @xmp = Nokogiri::XML(string)
  end

  def get_tags
    xmp.css("dc|subject rdf|li", NAMESPACES).map do |tag|
      tag.text
    end
  end
end
