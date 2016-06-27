require "gtk3"

class PhotoWindow
  def initialize
    @image = Gtk::Image.new.tap do |o|
      o.set_size_request(400, 400)
    end

    # Put @image into an event box so it can get mouse clicks and
    # drags.

    @event_box = Gtk::EventBox.new
    @event_box.add(@image)

    @scale = :fit

    @image.signal_connect("size-allocate") do |widget, rectangle|
      show_pixbuf
    end

    @event_box.signal_connect("button-press-event") do |widget, event|
      puts "button-press-event"
      @x = event.x
      @y = event.y
      false
    end

    @event_box.signal_connect("motion-notify-event") do |widget, event|
      puts "motion-notify-event #{event.x - @x} #{event.y - @y}"
      false
    end
  end

  def set_scale(scale)
    @scale = scale
    show_pixbuf
  end

  def show_photo(filename)
    pixbuf = filename && Gdk::Pixbuf.new(file: filename)
    show_pixbuf(pixbuf)
  end

  def show_pixbuf(pixbuf = @pixbuf)
    @pixbuf = pixbuf

    if @pixbuf
      scale =
        case @scale
        when :fit
          compute_scale_to_fit(@image, @pixbuf)
        else
          @scale
        end

      if scale != @last_scale || pixbuf != @last_pixbuf
        @last_scale = scale
        @last_pixbuf = pixbuf

        scaled = @pixbuf.scale(pixbuf.width * scale, pixbuf.height * scale)
        @image.set_pixbuf(scaled)
      end
    else
      @image.set_pixbuf(nil)
    end
  end

  def compute_scale_to_fit(image, pixbuf)
    image_width = image.allocated_width
    pixbuf_width = pixbuf.width
    width_scale = image_width.to_f / pixbuf_width

    image_height = image.allocated_height
    pixbuf_height = pixbuf.height
    height_scale = image_height.to_f / pixbuf_height

    scale = width_scale < height_scale ? width_scale : height_scale
    if scale > 1
      scale = 1
    end
    scale
  end

  # This is only for packing the window layout, yuck.
  #
  def get_widget
    @event_box
  end
end
