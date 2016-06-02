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
    # Create the widgets we actually care about and save in instance
    # variables and use.  Then lay them out.

    @applied_tags_list = Gtk::ListStore.new(String)
    @applied_tags = Gtk::TreeView.new(@applied_tags_list).with do
      set_enable_search(false)
      selection.set_mode(Gtk::SelectionMode::NONE)
      renderer = Gtk::CellRendererText.new
      # Fixed text property:
      # renderer.set_text("blah")
      # renderer.set_property("text", "blah")
      column = Gtk::TreeViewColumn.new("Applied tags", renderer).with do
        # Get text from column 0 of the model:
        add_attribute(renderer, "text", 0)
        # Use a block to set/unset dynamically computed properties on
        # the renderer:
        # set_cell_data_func(renderer) do |tree_view_column, renderer, model, iter|
        #  renderer.set_text("wow")
        # end
      end
      append_column(column)
    end

    @available_tags_list = Gtk::ListStore.new(String)
    @available_tags = Gtk::TreeView.new(@available_tags_list).with do
      set_enable_search(false)
      selection.set_mode(Gtk::SelectionMode::NONE)
      renderer = Gtk::CellRendererText.new
      # Fixed text property:
      # renderer.set_text("blah")
      # renderer.set_property("text", "blah")
      column = Gtk::TreeViewColumn.new("Available tags", renderer).with do
        # Get text from column 0 of the model:
        add_attribute(renderer, "text", 0)
      end
      append_column(column)
    end

    @tag_entry = Gtk::Entry.new

    @image = Gtk::Image.new

    # Widget layout.  The tag TreeViews get wrapped in ScrolledWindows
    # and put into a Paned.  @tag_entry goes into a Box with
    # @available_tags and the Box goes in the lower pane.

    # "Often, it is useful to put each child inside a Gtk::Frame with
    # the shadow type set to Gtk::SHADOW_IN so that the gutter appears
    # as a ridge."

    paned = Gtk::Paned.new(:vertical)

    scrolled = Gtk::ScrolledWindow.new.with do
      set_hscrollbar_policy(:never)
      set_vscrollbar_policy(:automatic)
    end
    scrolled.add(@applied_tags)
    paned.pack1(scrolled, resize: true, shrink: false)

    scrolled = Gtk::ScrolledWindow.new.with do
      set_hscrollbar_policy(:never)
      set_vscrollbar_policy(:automatic)
      #set_shadow_type(:etched_out)
    end
    scrolled.add(@available_tags)

    box = Gtk::Box.new(:vertical)
    box.pack_start(@tag_entry, expand: false)
    box.pack_start(scrolled, expand: true, fill: true)
    paned.pack2(box, resize: true, shrink: false)
    #paned.position = ??

    box = Gtk::Box.new(:horizontal)
    box.pack_start(paned, expand: false)

    # Put @image into an event box so it can get mouse clicks and
    # drags.

    @image.set_size_request(400, 400)
    event_box = Gtk::EventBox.new
    event_box.add(@image)
    box.pack_start(event_box, expand: true, fill: true)
#    event_box.signal_connect("button_press_event") do
#      puts "Clicked."
#    end

    # Finally, the top-level window.

    window = Gtk::Window.new.with do
      set_title("Viewer")
      # override_background_color(:normal, Gdk::RGBA::new(0.2, 0.2, 0.2, 1))
      set_default_size(300, 280)
      set_position(:center)
    end
    window.add(box)

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

class Object
  def with(&block)
    instance_exec(&block)
    self
  end
end

Viewer.new(ARGV[0] || ".")
Gtk.main
