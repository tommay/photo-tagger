#!/usr/bin/env ruby

require "bundler/setup"
require "gtk3"
require "byebug"

require_relative "model"
require_relative "files"
require_relative "importer"
require_relative "savelist"

class Viewer
  def initialize(filename)
    case
    when !filename || File.directory?(filename)
      @filenames = Files.for_directory(filename)
      @nfile = 0
    when File.exist?(filename)
      set_filename(filename)
    else
      puts "#{filename} not found"
      exit(1)
    end

    init_ui

    load_photo(@filenames[@nfile])

    @recent = SaveList.new([])
  end

def set_filename(filename)
    # If filename is a directory set dirname to its directorey, else to nil.
    if filename =~ /#{Regexp.quote(File::SEPARATOR)}/
      dirname = File.dirname(filename)
    end
    @filenames = Files.for_directory(dirname)
    @nfile = @filenames.find_index(filename)
  end

  # The tag TreeViews are all nearly the same, so create them here.
  #
  def create_treeview(name)
    tags_list = Gtk::ListStore.new(String)
    tags_view = Gtk::TreeView.new(tags_list).tap do |o|
      o.headers_visible = false
      o.enable_search = false
      o.selection.mode = Gtk::SelectionMode::NONE
      renderer = Gtk::CellRendererText.new
      # Fixed text property:
      # renderer.set_text("blah")
      # renderer.set_property("text", "blah")
      column = Gtk::TreeViewColumn.new("Applied tags", renderer).tap do |o|
        # Get text from column 0 of the model:
        o.add_attribute(renderer, "text", 0)
        # Use a block to set/unset dynamically computed properties on
        # the renderer:
        # o.set_cell_data_func(renderer) do |tree_view_column, renderer, model, iter|
        #  renderer.set_text("wow")
        #  end
      end
      o.append_column(column)
    end
    [tags_list, tags_view]
  end

  def init_ui
    # Create the widgets we actually care about and save in instance
    # variables and use.  Then lay them out.

    @applied_tags_list, @applied_tags = create_treeview("Applied tags")
    @applied_tags.headers_visible = true

    @available_tags_list, @available_tags = create_treeview("Available tags")
    @directory_tags_list, @directory_tags = create_treeview("Directory tags")

    @tag_entry = Gtk::Entry.new.tap do |o|
      # The completion list intentionally uses all tags, instead of
      # using the list selected in the notebook tab.  This seems more
      # useful.  Time will tell.
      @tag_completion = Gtk::EntryCompletion.new.tap do |o|
        o.model = @available_tags_list
        o.text_column = 0
        o.inline_completion = true
        o.popup_completion = true
        o.popup_single_match = false
      end
      o.completion = @tag_completion
    end

    # XXX what I want is to click on a completion in the popup to set the tag,
    # but iter isn't working here.

    #@tag_completion.signal_connect("match-selected") do |widget, model, iter|
    #  puts "Got #{iter[0]}"
    #  false
    #end

    @image = Gtk::Image.new

    # Widget layout.  The tag TreeViews get wrapped in ScrolledWindows
    # and put into a Paned.  @tag_entry goes into a Box with
    # @available_tags and the Box goes in the lower pane.

    # "Often, it is useful to put each child inside a Gtk::Frame with
    # the shadow type set to Gtk::SHADOW_IN so that the gutter appears
    # as a ridge."

    paned = Gtk::Paned.new(:vertical)

    scrolled = Gtk::ScrolledWindow.new.tap do |o|
      o.hscrollbar_policy = :never
      o.vscrollbar_policy = :automatic
      # I want the scrollbars on whenever the window has enough content.
      o.overlay_scrolling = false
    end
    scrolled.add(@applied_tags)
    paned.pack1(scrolled, resize: true, shrink: false)

    # Make the available tags treeviews scrollable, and put them in a notebook
    # with a page for each type (all, directory, etc.).

    notebook = Gtk::Notebook.new.tap do |o|
      # Allow scrolling if there are too many tabs.
      o.scrollable = true
    end

    [["Dir", @directory_tags], ["All", @available_tags]].each do |name, treeview|
      scrolled = Gtk::ScrolledWindow.new.tap do |o|
        o.hscrollbar_policy = :never
        o.vscrollbar_policy = :automatic
        o.overlay_scrolling = false
        #o.shadow_type(:etched_out)
      end
      scrolled.add(treeview)

      label = Gtk::Label.new(name)
      notebook.append_page(scrolled, label)
    end

    # Box up @tag_entry and notebook.

    box = Gtk::Box.new(:vertical)
    box.pack_start(@tag_entry, expand: false)
    box.pack_start(notebook, expand: true, fill: true)
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

    @window = Gtk::Window.new.tap do |o|
      o.title = "Viewer"
      # o.override_background_color(:normal, Gdk::RGBA::new(0.2, 0.2, 0.2, 1))
      o.set_default_size(300, 280)
      o.position = :center
    end
    @window.add(box)

    @image.signal_connect("size-allocate") do |widget, rectangle|
      if @pixbuf
        show_scaled_image(@image, @pixbuf)
      end
    end

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

    @directory_tags.signal_connect("row-activated") do |widget, path, column|
      tag = widget.model.get_iter(path)[0]
      add_tag(tag)
    end

    load_available_tags

    @window.signal_connect("key_press_event") do |widget, event|
      # Gdk::Keyval.to_name(event.keyval)
      case event.keyval
      when Gdk::Keyval::KEY_Left
        prev_photo
      when Gdk::Keyval::KEY_Right
        next_photo
      when Gdk::Keyval::KEY_Delete
        delete_file
      when Gdk::Keyval::KEY_u
        undelete_file
      when Gdk::Keyval::KEY_s
        if event.state == Gdk::ModifierType::CONTROL_MASK
          save_last
          true
        end
      when Gdk::Keyval::KEY_r
        if event.state == Gdk::ModifierType::CONTROL_MASK
          restore_last
          true
        end
      when Gdk::Keyval::KEY_comma
        tags = @photo.tags.map {|t| t.tag}
        @photo.tags.clear
        @recent.older(tags).each do |t|
          @photo.add_tag(t)
        end
        @photo.save
        load_applied_tags
      when Gdk::Keyval::KEY_period
        tags = @photo.tags.map {|t| t.tag}
        @photo.tags.clear
        @recent.newer(tags).each do |t|
          @photo.add_tag(t)
        end
        @photo.save
        load_applied_tags
      end
    end

    @window.signal_connect("destroy") do
      save_last
      Gtk.main_quit
    end

    #@window.maximize
    @window.show_all
  end

  def load_photo(filename)
    @photo = filename &&
             Importer.find_or_import_from_file(
               filename, copy_tags: true, purge_identical_images: true)
    load_applied_tags
    load_directory_tags
    show_filename
    show_photo
  end

  def save_recent_tags
    tags = @photo.tags.map do |t|
      t.tag
    end
    @recent.add(tags)
  end

  def next_photo(delta = 1)
    save_recent_tags
    if @filenames.size > 0
      @nfile = (@nfile + delta) % @filenames.size
    end
    load_photo(@filenames[@nfile])
  end

  def prev_photo
    next_photo(-1)
  end

  def show_filename
    @window.title = "Viewer: #{@photo && @photo.filename}"
  end

  def show_photo
    if @photo
      @pixbuf = Gdk::Pixbuf.new(file: @photo.filename)
      show_scaled_image(@image, @pixbuf)
    else
      @image.set_pixbuf(nil)
    end
  end

  def show_scaled_image(image, pixbuf)
    image_width = image.allocated_width
    image_height = image.allocated_height
    if !@last_image_size || @last_image_size != [image_width, image_height] ||
       @last_pixbuf != pixbuf
      @last_image_size = [image_width, image_height]
      @last_pixbuf = pixbuf
      pixbuf_width = pixbuf.width
      pixbuf_height = pixbuf.height
      width_ratio = image_width.to_f / pixbuf_width
      height_ratio = image_height.to_f / pixbuf_height
      ratio = width_ratio < height_ratio ? width_ratio : height_ratio
      scaled = @pixbuf.scale(pixbuf_width * ratio, pixbuf_height * ratio)
      image.set_pixbuf(scaled)
    end
  end

  def add_tag(string)
    if @photo.add_tag(string)
      load_applied_tags
      load_available_tags
      load_directory_tags
    end
  end

  def remove_tag(string)
    if @photo.remove_tag(string)
      load_applied_tags
      load_directory_tags
    end
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

  def load_directory_tags
    @directory_tags_list.clear
    if @photo
      Photo.all(directory: @photo.directory).tags.each do |tag|
        @directory_tags_list.append[0] = tag.tag
      end
    end
  end

  # XXX Wow this is ugly.
  #
  def delete_file
    photo_filename = @photo.filename
    photo_dirname = File.dirname(photo_filename)
    deleted_dirname = File.join(photo_dirname, ".deleted")
    begin
      Dir.mkdir(deleted_dirname)
    rescue Errno::EEXIST => ex
    end
    File.basename(photo_filename) =~ /^([^.]+)/
    base = $1

    # Remember the last file deleted for crufty undelete.

    @deleted_filename = @filenames[@nfile]
    @deleted_nfile = @nfile
    @deleted_files = []
    Dir[File.join(photo_dirname, "#{base}.*")].each do |n|
      deleted = File.join(deleted_dirname, File.basename(n))
      File.rename(n, deleted)
      @deleted_files << [n, deleted]
    end

    # XXX handle when there is no next.

    @filenames.delete_at(@nfile)
    if @nfile >= @filenames.size
      @nfile -= 1
    end
    load_photo(@filenames[@nfile])
  end

  # XXX this is super-crufty.
  #
  def undelete_file
    if @deleted_files
      @deleted_files.each do |name, deleted|
        File.rename(deleted, name)
      end
      @deleted_files = nil

      @nfile = @deleted_nfile
      @filenames.insert(@nfile, @deleted_filename)

      load_photo(@filenames[@nfile])
    end
  end

  def save_last
    if @photo
      last = Last.first_or_new(directory: @photo.directory)
      last.filename = @photo.filename
      last.save
    end
  end

  def restore_last
    if @photo
      last = Last.get(@photo.directory)
      if last
        filename = last.filename
        if File.exist?(filename)
          set_filename(filename)
          load_photo(filename)
        end
      end
    end
  end
end

# ARGV[0] might be nil, in which case we'll show the image files in
# the current directory without "./" in their path.
Viewer.new(ARGV[0])
Gtk.main
