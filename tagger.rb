#!/usr/bin/env ruby

require "pathname"
ENV["BUNDLE_GEMFILE"] = Pathname.new(__FILE__).realpath.dirname.join("Gemfile").to_s

require "bundler/setup"
require "set"
require "gtk3"
require "fileutils"
require "byebug"

require_relative "model"
require_relative "photo_window"
require_relative "files"
require_relative "file_list"
require_relative "importer"
require_relative "savelist"
require_relative "entry_dialog"
require_relative "restore"

class Tagger
  def initialize(args)
    init_ui
    @recent = SaveList.new([])
    set_filename(args)
  end

  def init_ui
    # Create the widgets we actually care about and save in instance
    # variables and use.  Then lay them out.

    @rating = Gtk::Label.new

    # Applied tags aren't sorted.  It's more intuitive to leave them
    # in the order they're added at first.  XXX might want to add a column
    # to photo_tags for this.

    @applied_tags_list, applied_tags =
      create_treeview("Applied tags", sorted: false)
    #applied_tags.headers_visible = true

    @available_tags_list, available_tags = create_treeview("Available tags")
    @directory_tags_list, @directory_tags = create_treeview("Directory tags")

    # Searching a Gtk::ListStore is noticeably slow, especially if the
    # item isn't found or is near the end of the list.  So maintain an
    # auxiliary set of the tags in the list for fast determination of
    # whether a tag is already in the list.

    @available_tags_set = Set.new

    @tag_entry = Gtk::Entry.new.tap do |o|
      # The completion list intentionally uses all tags, instead of
      # using the list selected in the notebook tab.  This seems more
      # useful.  Time will tell.
      tag_completion = Gtk::EntryCompletion.new.tap do |o|
        o.model = @available_tags_list
        o.text_column = 0
        o.inline_completion = true
        o.popup_completion = true
        o.popup_single_match = false
      end
      o.completion = tag_completion

      # XXX what I want is to click on a completion in the popup to
      # set the tag, but iter is null here.

      #tag_completion.signal_connect("match-selected") do |widget, model, iter|
      #  puts "Got #{iter[0]}"
      #end
    end

    @photo_window = PhotoWindow.new

    # Widget layout.  The tag TreeViews get wrapped in
    # ScrolledWindows.  There are two panes, upper and lower, whose
    # boundary can be dragged up and down.  The upper pane gets a box
    # containing @rating, applied_tags, and @textentry.  The lower
    # pane gets a notebook containing directory_tags and
    # available_tags.

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
    scrolled.add(applied_tags)

    # Box up @rating, applied_tags's ScrollWindow, and @tag_entry.

    box = Gtk::Box.new(:vertical)
    box.pack_start(@rating, expand: false)
    box.pack_start(scrolled, expand: true, fill: true)
    box.pack_start(@tag_entry, expand: false)

    # Put the box in the upper pane.

    paned.pack1(box, resize: true, shrink: false)

    # Make the available tags treeviews scrollable, and put them in a notebook
    # with a page for each type (all, directory, etc.).

    notebook = Gtk::Notebook.new.tap do |o|
      # Allow scrolling if there are too many tabs.
      o.scrollable = true
    end

    [["Dir", @directory_tags], ["All", available_tags]].each do |name, treeview|
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

    # Put the notebook in the lower pane.

    paned.pack2(notebook, resize: true, shrink: false)
    #paned.position = ??

    # The Paned and the PhotoWindow go left and right.

    box = Gtk::Box.new(:horizontal)
    box.pack_start(paned, expand: false)
    box.pack_start(@photo_window.get_widget, expand: true, fill: true)

    # Finally, put the box in the top-level window.

    @window = Gtk::Window.new.tap do |o|
      o.title = "Tagger"
      # o.override_background_color(:normal, Gdk::RGBA::new(0.2, 0.2, 0.2, 1))
      o.set_default_size(300, 280)
      o.position = :center
    end
    @window.add(box)

    @tag_entry.signal_connect("activate") do |widget|
      tag = widget.text.strip
      widget.set_text("")
      if tag != ""
        add_tag(tag)
      end
    end

    applied_tags.signal_connect("button-release-event") do |widget, event|
      if event.state == Gdk::ModifierType::BUTTON1_MASK
#        byebug
#        tag = widget.model.get_iter(path)[0]
#        puts "Clicked."
      end
    end

    applied_tags.signal_connect("row-activated") do |widget, path, column|
      tag = widget.model.get_iter(path)[0]
      remove_tag(tag)
    end

    available_tags.signal_connect("row-activated") do |widget, path, column|
      tag = widget.model.get_iter(path)[0]
      add_tag(tag)
    end

    @directory_tags.signal_connect("row-activated") do |widget, path, column|
      tag = widget.model.get_iter(path)[0]
      add_tag(tag)
    end

    # When we start typing with the focus on one of the treeviews,
    # move the focus to the @tag_entry instead of making the user do
    # it manually after realizing @tag_entry isn't focused.

    [applied_tags, available_tags, @directory_tags].each do |treeview|
      treeview.signal_connect("key-press-event") do |widget, event|
        if event.string >= "a" && event.string <= "z"
          @tag_entry.grab_focus
          @tag_entry.event(event)
        end
        false
      end
    end

    load_available_tags

    @window.signal_connect("key-press-event") do |widget, event|
      # Gdk::Keyval.to_name(event.keyval)
      case event.keyval
      when Gdk::Keyval::KEY_Left
        prev_photo
      when Gdk::Keyval::KEY_Right
        next_photo
      when Gdk::Keyval::KEY_Delete
        @photo && delete_photo
      when Gdk::Keyval::KEY_d
        if event.state == Gdk::ModifierType::CONTROL_MASK
          switch_to_from_deleted_directory
          true
        end
      when Gdk::Keyval::KEY_z
        if event.state == Gdk::ModifierType::CONTROL_MASK
          if @restore
            @restore.call
            @restore = nil
          end
          true
        end
      when Gdk::Keyval::KEY_v
        if event.state == Gdk::ModifierType::CONTROL_MASK
          rename_directory_dialog
          true
        end
      when Gdk::Keyval::KEY_n
        if event.state == Gdk::ModifierType::CONTROL_MASK
          next_directory
          true
        end
      when Gdk::Keyval::KEY_p
        if event.state == Gdk::ModifierType::CONTROL_MASK
          prev_directory
          true
        end
      when Gdk::Keyval::KEY_6
        if event.state == Gdk::ModifierType::CONTROL_MASK
          crop_6mm
          true
        end
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
      when Gdk::Keyval::KEY_m
        if event.state == Gdk::ModifierType::CONTROL_MASK
          @photo && move_photo_dialog
          true
        end
      when Gdk::Keyval::KEY_comma
        if event.state == Gdk::ModifierType::CONTROL_MASK
          rotate_left
        else
          use_recent_tags(:older)
        end
        true
      when Gdk::Keyval::KEY_period
        if event.state == Gdk::ModifierType::CONTROL_MASK
          rotate_right
        else
          use_recent_tags(:newer)
        end
        true
      when Gdk::Keyval::KEY_9
        if !tagging?
          @photo_window.set_scale(1)
          true
        else
          false
        end
      when Gdk::Keyval::KEY_0
        if !tagging?
          @photo_window.set_scale(:fit)
          true
        else
          false
        end
      when Gdk::Keyval::KEY_1 .. Gdk::Keyval::KEY_5
        if @photo && !tagging?
          @restore = Restore.new(@photo, @photo.rating) do |photo, rating|
            photo.set_rating(rating)
            @file_list.set_current(photo.filename)
            load_photo(@file_list.current)
          end

          @photo.set_rating(event.keyval - Gdk::Keyval::KEY_0)

          if event.state != Gdk::ModifierType::CONTROL_MASK
            next_photo do |filename|
              photo = import_photo(filename)
              !photo.rating
            end
          else
            show_rating
          end
          true
        else
          false
        end
      end
    end

    @window.signal_connect("destroy") do
      save_last
      Gtk.main_quit
    end

    #@window.maximize
    @window.show_all
  end

  def tagging?
    @tag_entry.has_focus? && @tag_entry.text != ""
  end

  # The tag TreeViews are all nearly the same, so create them here.
  #
  def create_treeview(name, sorted: true)
    tags_list = Gtk::ListStore.new(String).tap do |o|
      if sorted
        o.set_sort_column_id(0, Gtk::SortType::ASCENDING)
      end
    end
    tags_view = Gtk::TreeView.new(tags_list).tap do |o|
      o.headers_visible = false
      o.enable_search = false
      o.selection.mode = Gtk::SelectionMode::NONE
      o.activate_on_single_click = true
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

  def set_filename(filename)
    @file_list = FileList.new(filename)
    load_photo(@file_list.current)
  end

  def load_photo(filename)
    @photo = filename && import_photo(filename)
    load_applied_tags
    load_directory_tags
    show_filename
    show_rating
    show_photo
  end

  def import_photo(filename)
    Importer.find_or_import_from_file(
      filename, copy_tags: true, purge_identical_images: true)
  end

  def save_recent_tags
    tags = @photo.tags.map do |t|
      t.tag
    end
    @recent.add(tags)
  end

  def use_recent_tags(older_or_newer)
    if @photo
      current_tags = @photo.tags.map {|t| t.tag}
      new_tags = @recent.send(older_or_newer, current_tags)
      Photo.transaction do
        (current_tags - new_tags).each do |tag|
          @photo.remove_tag(tag)
        end
        (new_tags - current_tags).each do |tag|
          @photo.add_tag(tag)
        end
        @photo.save
      end
      load_applied_tags
    end
  end

  def next_photo(delta = 1, &block)
    if @photo
      save_recent_tags
      load_photo(@file_list.next(delta, &block))
    end
  end

  def prev_photo
    next_photo(-1)
  end

  def next_directory(delta = 1)
    parent = File.dirname(@file_list.directory)
    siblings = Dir[File.join(parent, "*")].select{|x| File.directory?(x)}.sort
    index = siblings.index(@file_list.directory)
    if index
      index += delta
      if index >= 0 && index < siblings.size
        set_filename(siblings[index])
      end
    end
  end

  def prev_directory
    next_directory(-1)
  end

  def show_filename
    @window.title = "Tagger: #{@photo ? @photo.filename : @file_list.directory}"
  end

  def show_rating
    @rating.set_text(@photo && @photo.rating ? "*" * @photo.rating : "")
  end

  def show_photo
    @photo_window.show_photo(@photo && @photo.filename)
  end

  def add_tag(string)
    if @photo && @photo.add_tag(string)
      load_applied_tags
      add_available_tag(string)
      load_directory_tags
    end
  end

  def remove_tag(string)
    if @photo && @photo.remove_tag(string)
      load_applied_tags
      load_directory_tags
    end
  end

  def load_applied_tags
    @applied_tags_list.clear
    if @photo
      @photo.tags.each do |tag|
        @applied_tags_list.append[0] = tag.tag
      end
    end
  end

  def load_available_tags
    # Disable sorting while the list is loaded.
    sort_column_id = @available_tags_list.sort_column_id[1,2]
    begin
      #@available_tags_list.set_sort_column_id(-1, :ascending)
      #@available_tags_list.set_default_sort_func{-1}
      @available_tags_list.clear
      Tag.all.each do |tag|
        @available_tags_list.append[0] = tag.tag
        @available_tags_set << tag.tag
      end
    ensure
      #@available_tags_list.set_sort_column_id(*sort_column_id)
    end
  end

  def add_available_tag(tag)
    if !@available_tags_set.include?(tag)
      @available_tags_list.append[0] = tag
      @available_tags_set << tag
    end
  end

  def load_directory_tags
    @directory_tags_list.clear
    Photo.all(directory: @file_list.directory).tags.each do |tag|
      @directory_tags_list.append[0] = tag.tag
    end
    restore_scroll_when_idle(@directory_tags)
  end

  # XXX Wow this is ugly.
  #
  def delete_photo
    # If we're not in a .deleted directory, then delete by creating
    # and renaming to a .deleted subdirectory.  If we're in a .deleted
    # directory, then delete by renaming/restoring to the parent
    # directory.

    dst_dirname =
      if File.basename(@file_list.directory) != ".deleted"
        create_deleted_dir(@file_list.directory)
      else
        File.dirname(@file_list.directory)
      end

    # Remember all the "deleted" files for crufty restore.

    _moved_files = move_related_files(@photo.filename, dst_dirname)

    # Delete from files_list and remember the last file deleted for
    # crufty restore.

    _restore_current = @file_list.delete_current

    @restore = Restore.new do
      restore_photo(_moved_files, _restore_current)
    end

    load_photo(@file_list.current)
  end

  def move_related_files(filename, dst_dir)
    # Move everything with the same basename regardless of suffix.

    src_dir = File.dirname(filename)
    File.basename(filename) =~ /^(.*)\./
    base = $1

    Dir[File.join(src_dir, "#{base}.*")].map do |src_name|
      dst_name = File.join(dst_dir, File.basename(src_name))
      File.rename(src_name, dst_name)
      [src_name, dst_name]
    end
  end

  # XXX this is super-crufty.
  #
  def restore_photo(moved_files, restore_current)
    moved_files.each do |name, deleted|
      File.rename(deleted, name)
      # If there is a database entry for this file then make sure
      # its sha1 is up to date.
      photo = Photo.find(name)
      if photo
        photo.set_sha1
        photo.save
      end
    end

    # XXX It would be cleaner just to do set_filename and have it
    # reload the directory.  It should be performant.

    restore_current.call

    load_photo(@file_list.current)
  end

  def switch_to_from_deleted_directory
    if File.basename(@file_list.directory) == ".deleted"
      parent = File.dirname(@file_list.directory)
      set_filename(parent)
    else
      deleted_directory = File.join(@file_list.directory, ".deleted")
      if File.exist?(deleted_directory)
        set_filename(deleted_directory)
      end
    end
  end

  def rename_directory_dialog
    EntryDialog.new(
      title: "Rename Directory", parent: @window,
      text: @file_list.directory,
      width_chars: @file_list.directory.size + 20) do |text|
      begin
        rename_photos_directory(text)
      rescue => ex
        error_dialog("#{text}: #{ex}")
      end
    end
  end

  def error_dialog(msg)
    dialog = Gtk::MessageDialog.new(
      type: Gtk::MessageType::ERROR,
      message: msg,
      buttons: :ok,
      parent: @window,
      flags: Gtk::DialogFlags::DESTROY_WITH_PARENT)
    dialog.run
    dialog.destroy
  end

  # XXX This breaks deleted files.
  def rename_photos_directory(new_directory)
    if File.exist?(new_directory)
      raise "#{new_directory} already exists"
    end
    File.rename(@file_list.directory, new_directory)

    Photo.transaction do
      Photo.all(directory: @file_list.directory)
        .update(directory: new_directory)
    end

    set_filename(File.join(new_directory, @photo.basename))
  end

  def transform(*args)
    return if !@photo
    return if File.basename(@file_list.directory) == ".deleted"

    # Transform the file, and create a .bak file.

    msg = IO.popen(["/usr/bin/env"] + args, err: [:child, :out]) do |pipe|
      pipe.readlines(nil).first.chomp
    end
    if !$?.success?
      error_dialog(msg)
      return
    end

    # Update the sha1.

    @photo.set_sha1
    @photo.save

    # Move the .bak file to .deleted with the original filename.  This
    # makes it look like we deleted the file.  Unless there is already
    # an existing "deleted" file, in which case just leave it.  This
    # allows multiple rotations to be undone by restoring the original
    # backup.

    deleted_dirname = create_deleted_dir(@file_list.directory)
    deleted_filename = File.join(deleted_dirname, @photo.basename)
    if !File.exist?(deleted_filename)
      File.rename("#{@photo.filename}.bak", deleted_filename)
    end

    # Set things up so the file can be restored with restore.

    _moved_files = [[@photo.filename, deleted_filename]]
    _restore_current = @file_list.restore_current

    @restore = Restore.new do
      restore_photo(_moved_files, _restore_current)
    end

    # Show the transformed photo.

    load_photo(@file_list.current)
  end

  def crop_6mm
    # Losslessly crop and create a .bak file.

    transform("6mm", @photo.filename)
  end

  def rotate_left
    transform("jrot", "-l", @photo.filename)
  end

  def rotate_right
    transform("jrot", "-r", @photo.filename)
  end

  def create_deleted_dir(directory)
    File.join(directory, ".deleted").tap do |deleted_dirname|
      if !File.exist?(deleted_dirname)
        Dir.mkdir(deleted_dirname)
      end
    end
  end

  def move_photo_dialog
    last =
      if @move_last_directory == @file_list.directory
        @move_last
      else
        @file_list.directory
      end
    EntryDialog.new(
      title: "Move To", parent: @window,
      text: last,
      width_chars: @file_list.directory.size + 20) do |text|
      begin
        move_photo(@photo, text)
        @move_last = text
        @move_last_directory = @file_list.directory
      rescue => ex
        dialog = Gtk::MessageDialog.new(
          type: Gtk::MessageType::ERROR,
          message: "#{text}: #{ex}",
          buttons: :ok,
          parent: @window,
          flags: Gtk::DialogFlags::DESTROY_WITH_PARENT)
        dialog.run
        dialog.destroy
      end
    end
  end

  def move_photo(photo, new_directory)
    if !File.exist?(new_directory) # XXX && ask_create(new_directory)
      FileUtils.mkdir_p(new_directory)
    end

    @moved_files = move_related_files(photo.filename, new_directory)
    @deleted = @file_list.delete_current

    photo.directory = new_directory
    photo.save

    load_photo(@file_list.current)
  end

  def save_last
    if @photo
      last = Last.first_or_new(directory: @file_list.directory)
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

  def restore_scroll_when_idle(scrolled)
    adjustment = scrolled.vadjustment
    restore_scroll = Restore.new(adjustment.value) do |value|
      adjustment.set_value(value)
    end
    when_idle(&restore_scroll)
  end

  def when_idle(&block)
    id = GLib::Idle.add do
      block.call
      GLib::Source.remove(id)
    end
  end
end

Tagger.new(ARGV)
Gtk.main
