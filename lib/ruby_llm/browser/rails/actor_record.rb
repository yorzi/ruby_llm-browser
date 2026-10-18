# frozen_string_literal: true

module RubyLLM
  module Browser
    module Rails
      # A durable mutex per actor. Locking an empty set of operations cannot serialize
      # the first two reservations, so reservations first write this shared row.
      class ActorRecord < ActiveRecord::Base
        self.table_name = "ruby_llm_browser_actors"
      end
    end
  end
end
