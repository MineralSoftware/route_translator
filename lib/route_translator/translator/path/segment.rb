module RouteTranslator
  module Translator
    module Path
      module Segment
        class << self
          private

          def translate_string(str, locale, ancestors)
            dup_ancestors = ancestors.dup
            locale = locale.to_s.gsub('native_', '')
            opts = { scope: :routes, locale: locale }
            if RouteTranslator.config.disable_fallback && locale.to_s != I18n.default_locale.to_s
              opts[:fallback] = true
            else
              opts[:default] = str
            end

            dup_opts = opts.merge(throw: true)
            dup_opts.delete(:default)
            res = find_nested_translation(dup_ancestors, dup_opts, str)
            res = I18n.translate(str, opts) if res.is_a?(I18n::MissingTranslation)
            URI.escape(res)
          end

          def find_nested_translation(ancestors, opts, str)
            if ancestors.empty?
              res = catch(:exception) do
                I18n.translate(str + '._', opts)
              end
            else
              ancestors << str
              res = catch(:exception) do
                I18n.translate(ancestors.join('.'), opts)
              end
            end
            res
          end
        end

        module_function

        # Translates a single path segment.
        #
        # If the path segment contains something like an optional format
        # "people(.:format)", only "people" will be translated.
        # If there is no translation, the path segment is blank, begins with a
        # ":" (param key) or "*" (wildcard), the segment is returned untouched.
        def translate(segment, locale, ancestors)
          return segment if segment.empty?
          named_param, hyphenized = segment.split('-'.freeze, 2) if segment.starts_with?(':'.freeze)
          return "#{named_param}-#{translate(hyphenized.dup, locale, ancestors)}" if hyphenized
          return segment if segment.starts_with?('('.freeze) || segment.starts_with?('*'.freeze) || segment.include?(':'.freeze)

          appended_part = segment.slice!(/(\()$/)
          match = TRANSLATABLE_SEGMENT.match(segment)[1] if TRANSLATABLE_SEGMENT.match(segment)

          (translate_string(match, locale, ancestors) || segment) + appended_part.to_s
        end
      end
    end
  end
end
