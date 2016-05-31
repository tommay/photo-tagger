#!/usr/bin/env ruby

require "gtk3"
require "byebug"

builder = Gtk::Builder.new
builder.add_from_file("viewer.ui")

window = builder.get_object("the_window")
window.signal_connect("destroy") { Gtk.main_quit }
window.show_all
Gtk.main
