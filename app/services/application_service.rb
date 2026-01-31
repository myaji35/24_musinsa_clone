# Base Service class for all service objects
# Provides common success/failure response patterns
class ApplicationService
  class Result
    attr_reader :success, :data, :error

    def initialize(success:, data: nil, error: nil)
      @success = success
      @data = data
      @error = error
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end

  # Class method for one-liner service calls
  def self.call(*args, **kwargs)
    new(*args, **kwargs).call
  end

  protected

  def success(data = nil)
    Result.new(success: true, data: data)
  end

  def failure(error)
    Result.new(success: false, error: error)
  end
end
