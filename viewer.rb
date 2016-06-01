#!/usr/bin/env ruby

require "bundler/setup"
require "gtk3"
require "byebug"

require_relative "model"

class Viewer
  SUFFIXES = [%r{.jpg$}i, %r{.png$}i]

  def initialize(filename)
    case
    when File.directory?(filename)
      @filenames = filter_by_suffix(Dir["#{filename}/*"])
      @nfile = 0
    when File.exist?(filename)
      dirname = File.dirname(filename)
      @filenames = filter_by_suffix(Dir["#{dirname}/*"])
      @nfile = @filenames.find_index(filename)
    else
      puts "#{filename} not found"
      exit(1)
    end

    init_ui

    load_photo(@filenames[@nfile])
  end

  def filter_by_suffix(filenames)
    filenames.select do |filename|
      SUFFIXES.any? do |suffix|
        filename =~ suffix
      end
    end
  end

  def init_ui
    builder = Gtk::Builder.new
    builder.add_from_file("viewer.ui")

    @image = builder["image"]
    @tag_entry = builder["tag_entry"]
    @applied_tags_list = builder["applied_tags_list"]
    @applied_tags = builder["applied_tags"]
    @available_tags_list = builder["available_tags_list"]
    @available_tags = builder["available_tags"]

    @tag_entry.signal_connect("activate") do |widget|
      tag = widget.text.strip
      widget.set_text("")
      if tag != ""
        add_tag(tag)
      end
    end

    @applied_tags.signal_connect("row-activated") do |widget, path, column|
      tag = widget.model.get_iter(path)[0]
      remove_tag(tag)
    end

    @available_tags.signal_connect("row-activated") do |widget, path, column|
      tag = widget.model.get_iter(path)[0]
      add_tag(tag)
    end

    load_available_tags

    window = builder.get_object("the_window")

    window.signal_connect("key_press_event") do |widget, event|
      # Gdk::Keyval.to_name(event.keyval)
      case event.keyval
      when Gdk::Keyval::KEY_Left
        prev_photo
      when Gdk::Keyval::KEY_Right
        next_photo
      end
    end

    window.signal_connect("destroy") do
      Gtk.main_quit
    end

    window.show_all
  end

  def load_photo(filename)
    @photo = filename && Photo.find_or_create(filename)
    load_applied_tags
    show_filename
    show_image
  end

  def next_photo(delta = 1)
    if @filenames.size > 0
      @nfile = (@nfile + delta) % @filenames.size
    end
    load_photo(@filenames[@nfile])
  end

  def prev_photo
    next_photo(-1)
  end

  def show_filename
    if @filename_label
      @filename_label.set_text(@photo && @photo.filename)
    end
  end

  def show_image
    if @photo
      pixbuf = Gdk::Pixbuf.new(file: @photo.filename)
      image_width = @image.allocated_width
      image_height = @image.allocated_height
      pixbuf_width = pixbuf.width
      pixbuf_height = pixbuf.height
      width_ratio = image_width.to_f / pixbuf_width
      height_ratio = image_height.to_f / pixbuf_height
      ratio = width_ratio < height_ratio ? width_ratio : height_ratio
      scaled = pixbuf.scale(pixbuf_width * ratio, pixbuf_height * ratio)
      @image.set_pixbuf(scaled)
    else
      @image.set_pixbuf(nil)
    end
  end

  def add_tag(string)
    # XXX I think this is supposed to work, but it only works if the tag
    # doesn't exist in which case it creates the tag and links it, else
    # it does nothing.
    # @photo.tags.first_or_create(tag: string)
    # So do it the hard way.
    tag = Tag.first_or_create(tag: string)
    if !@photo.tags.include?(tag)
      @photo.tags << tag
      @photo.save
    end
    load_applied_tags
  end

  def remove_tag(string)
    tag = @photo.tags.first(tag: string)
    @photo.tags.delete(tag)
    @photo.save
    load_applied_tags
  end

  def load_applied_tags
    @applied_tags_list.clear
    @photo.tags.each do |tag|
      @applied_tags_list.append[0] = tag.tag
    end
  end

  def load_available_tags
    @available_tags_list.clear
    Tag.all.each do |tag|
      @available_tags_list.append[0] = tag.tag
    end
  end
end

Viewer.new(ARGV[0] || ".")
Gtk.main
