# Note that Restore.new actually returns a lambda.

class Restore
  def self.new(*args, &block)
    lambda do
      block.call(args)
    end
  end
end
