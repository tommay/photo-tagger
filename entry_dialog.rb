require "gtk3"

class EntryDialog
  # insert_text will be inserted at the cursor when C-d is pressed.  This
  # is very inelegant but gets the job done for now.
  #
  def initialize(title:, parent:, text:, width_chars:, insert_text: nil,
                 &block)
    dialog = Gtk::Dialog.new(
      title: title, parent: parent,
      flags: Gtk::DialogFlags::DESTROY_WITH_PARENT,
      buttons: [
        ["Ok", Gtk::ResponseType::ACCEPT],
        ["Not so ok", Gtk::ResponseType::REJECT]])

    entry = Gtk::Entry.new.tap do |o|
      o.text = text
      o.width_chars = width_chars
      o.activates_default = true
    end

    # On C-d, insert the photo's date.

    entry.signal_connect("key-press-event") do |widget, event|
      case event.keyval
      when Gdk::Keyval::KEY_d
        if event.state == Gdk::ModifierType::CONTROL_MASK
          if insert_text
            widget.insert_at_cursor(insert_text)
            true
          end
        end
      end
    end

    # activates_default = true is supposed to do this but it doesn't.
    # So do it ourselves.

    entry.signal_connect("activate") do
      dialog.response(Gtk::ResponseType::ACCEPT)
    end

    dialog.child.add(entry)

    dialog.signal_connect("response") do |dialog, response_type|
      if response_type == Gtk::ResponseType::ACCEPT
        block.call(entry.text)
      end
      dialog.destroy
    end

    dialog.show_all

    # Finally it's effective to call select_region to position the
    # cursor after the text with nothing selected.

    entry.select_region(entry.text.size, entry.text.size)
  end
end
