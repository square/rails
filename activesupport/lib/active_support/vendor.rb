# Prefer gems to the bundled libs.
require 'rubygems'

require 'builder'
require 'memcache'
require 'tzinfo'
require 'i18n'

module I18n
  if !respond_to?(:normalize_translation_keys) && respond_to?(:normalize_keys)
    def self.normalize_translation_keys(*args)
      normalize_keys(*args)
    end
  end
end
