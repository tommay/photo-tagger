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
    @scale = 1
    @offset_x = 0
    @offset_y = 0

    @image.signal_connect("size-allocate") do |widget, rectangle|
      show_pixbuf
    end

    @event_box.signal_connect("button-press-event") do |widget, event|
      save_xy(event)
      false
    end

    @event_box.signal_connect("motion-notify-event") do |widget, event|
      if @scaled_pixbuf
        @offset_x -= event.x - @last_x
        @offset_y -= event.y - @last_y
        bound_offsets
        save_xy(event)
        show_scaled_pixbuf
      end

      false
    end
  end

  def save_xy(event)
    @last_x = event.x
    @last_y = event.y
  end

  def bound_offsets
    @offset_x = bound(
      @offset_x, 0,
      max(@scaled_pixbuf.width - @image.allocated_width, 0))

    @offset_y =
      bound(
        @offset_y, 0,
        max(@scaled_pixbuf.height - @image.allocated_height, 0))
  end

  def bound(val, min, max)
    case
    when val < min
      min
    when val > max
      max
    else
      val
    end
  end

  def max(a, b)
    a > b ? a : b
  end

  def min(a, b)
    a < b ? a : b
  end

  def set_scale(scale)
    @scale = scale
    if @pixbuf
      scale = compute_scale(@scale, @image, @pixbuf)
      @scaled_pixbuf = scale_pixbuf(@pixbuf, scale)
      show_scaled_pixbuf
    end
  end

  def show_photo(filename)
    @pixbuf = filename && Gdk::Pixbuf.new(file: filename)
    show_pixbuf
  end

  def show_pixbuf
    if @pixbuf
      scale = compute_scale(@scale, @image, @pixbuf)
      if scale != @last_scale || @pixbuf != @last_pixbuf
        @last_scale = scale
        @last_pixbuf = @pixbuf
        @scaled_pixbuf =
          @pixbuf.scale(@pixbuf.width * scale, @pixbuf.height * scale)
      end
      bound_offsets
      show_scaled_pixbuf
    else
      @image.set_pixbuf(nil)
    end
  end

  def show_scaled_pixbuf
    cropped = Gdk::Pixbuf.new(
      @scaled_pixbuf, @offset_x, @offset_y,
      min(@image.allocated_width, @scaled_pixbuf.width),
      min(@image.allocated_height, @scaled_pixbuf.height))
    @image.set_pixbuf(cropped)
  end

  def compute_scale(scale, image, pixbuf)
    case scale
    when :fit
      compute_scale_to_fit(image, pixbuf)
    else
      scale
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
    scale > 1 ? 1 : scale
  end

  # This is only for packing the window layout, yuck.
  #
  def get_widget
    @event_box
  end
end
