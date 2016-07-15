class SaveList
  def initialize(empty)
    @empty = empty.sort
    @list = [@empty]
    @pos = -1
  end

  def tags_lists(o)
    o.map do |list|
      list.map do |tag|
        tag.tag
      end
    end
  end

  def add(o)
    # XXX Element order doesn't really matter for comparison.  Use an
    # ordered set/hash to store the tags?
    sorted = o.sort
    @list.delete(sorted)
    @list.unshift(sorted)
    @list.delete(@empty)
    @list.unshift(@empty)
    @pos = 0
    #puts "add: #{o.inspect}"
    #puts "=> #{@list.inspect}"
  end

  # How should this work?
  # - go to the previous tags
  # - add a tag
  # - go the previus tags
  # - go back to the next tag
  # Seems like this should show the edited tags set.
  # But maybe not.
  def older(o)
    #puts "older: #{@pos}"
    # If we're at the newest end of the list, save a copy in @list[0]
    # so we can get back to it with newer.
    if @pos == 0
      @list[0] = o.sort
    end
    if @pos + 1 < @list.size
      if @list[@pos + 1] != @list[0]
        @pos += 1
      elsif @pos + 2 < @list.size
        @pos += 2
      end
    end
    @list[@pos].dup.tap do |x|
      #puts "older: #{@pos} => #{x.inspect} #{@list.inspect}"
    end
  end

  def newer(o)
    #puts "newer: #{@pos}"
    if @pos == 0
      # There is nothing newer.
      o.dup
    else
      if @pos - 1 >= 0
        if @pos - 1 == 0 || @list[@pos - 1] != @list[0]
          @pos -= 1
        elsif @pos - 2 >= 0
          @pos -= 2
        end
      end
      @list[@pos].dup.tap do |x|
        #puts "newer: #{@pos} => #{x.inspect} #{@list.inspect}"
      end
    end
  end
end
