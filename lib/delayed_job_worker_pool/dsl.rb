module DelayedJobWorkerPool
  class DSL
    class ConflictingWorkerConfiguration < StandardError; end
    class ContextError < StandardError; end

    POOL_SETTINGS = [:workers, :queues, :min_priority, :max_priority, :sleep_delay, :read_ahead].freeze
    CALLBACK_SETTINGS = [:after_preload_app, :on_worker_boot, :after_worker_boot, :after_worker_shutdown].freeze

    def self.load(path)
      new.instance_eval(File.read(path), path, 1).to_h
    end

    def initialize
      @options = {}
      @worker_pools = []
      @mode = nil
    end

    POOL_SETTINGS.each do |option_name|
      define_method(option_name) do |option_value|
        default_to_mode(:implicit_pool)
        set_pool_option(option_name, option_value) unless option_value.nil?
      end
    end

    def worker_pools(&block)
      use_mode!(:explicit_pools)
      yield
    end

    def worker_pool(&block)
      @current_pool = add_worker_pool
      yield
      @current_pool = nil
    end

    def preload_app(preload_app = true)
      @options[:preload_app] = preload_app
    end

    CALLBACK_SETTINGS.each do |option_name|
      define_method(option_name) do |&block|
        @options[option_name] = block
      end
    end

    def to_h
      @options.merge(worker_pools: @worker_pools)
    end

    private

    def set_pool_option(name, value)
      if @current_pool.nil?
        raise ContextError,
              'Are you mixing implicit and explicit worker configurations? Is your configration nested incorrectly?'
      end
      @current_pool[name] = value
    end

    def default_to_mode(mode)
      use_mode!(mode) if @mode.nil?
    end

    def use_mode!(mode)
      return if @mode == mode
      unless @mode.nil?
        raise ConflictingWorkerConfiguration,
              'You cannot mix configrations of implicit and explicit worker pool mode.'
      end

      @mode = mode
      @current_pool = add_worker_pool if @mode == :implicit_pool
    end

    def add_worker_pool
      options = {}
      @worker_pools << options
      options
    end
  end
end
