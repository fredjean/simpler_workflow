module SimplerWorkflow
  module OptionsAsMethods
    def method_missing(meth_name, *args)
      if @options.has_key?(meth_name.to_sym)
        @options[meth_name.to_sym] = args[0]
      else
        super
      end
    end
  end
end
