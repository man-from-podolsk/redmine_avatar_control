# frozen_string_literal: true

module RedmineAvatarControl
  # Administrator settings (Administration -> Plugins -> Avatar Control -> Configure).
  module Settings
    MODES = %w[all only_set none].freeze

    DEFAULTS = {
      # all       every user has an avatar: own picture, preset or Redmine's default (initials / Gravatar)
      # only_set  only avatars a user chose (picture or preset); nothing for the rest
      # none      no avatars anywhere
      'mode' => 'all',
      'hidden_project_ids' => [],
      'hide_in_subprojects' => '1',
      'allow_upload' => '1',
      'max_size_mb' => '5',
      'allow_presets' => '1',
      'allow_gravatar_presets' => '0',
      'allow_user_none' => '1',
      'allow_viewer_hide' => '1',
      # Extra elements hidden wherever avatars are hidden, e.g. the initials the Rubylode themes add
      # beside assignees with their own script
      'extra_hide_selectors' => '.assignee-initials'
    }.freeze

    module_function

    def all
      stored = Setting.plugin_redmine_avatar_control
      stored = stored.to_h if stored.respond_to?(:to_h) && !stored.is_a?(Hash)
      stored.is_a?(Hash) ? DEFAULTS.merge(stored.stringify_keys) : DEFAULTS
    rescue StandardError
      DEFAULTS
    end

    def mode
      MODES.include?(all['mode']) ? all['mode'] : 'all'
    end

    def flag?(name)
      all[name.to_s].to_s == '1'
    end

    def max_bytes
      mb = all['max_size_mb'].to_i
      mb = 5 if mb <= 0
      [mb, 20].min * 1024 * 1024
    end

    def hidden_project_ids
      Array(all['hidden_project_ids']).map(&:to_i).reject(&:zero?)
    end

    def project_hidden?(project)
      return false unless project.is_a?(Project) && project.id

      ids = hidden_project_ids
      return false if ids.empty?
      return true if ids.include?(project.id)

      flag?('hide_in_subprojects') && project.ancestors.where(id: ids).exists?
    end

    def viewer_hides_all?(viewer)
      flag?('allow_viewer_hide') && viewer.is_a?(User) && viewer.logged? &&
        viewer.pref[Choice::HIDE_ALL_KEY].to_s == '1'
    end

    # Whether avatars are hidden on the page being drawn
    def hidden_here?(project, viewer)
      mode == 'none' || viewer_hides_all?(viewer) || project_hidden?(project)
    end

    # CSS selectors from the settings, made safe for a <style> element
    def extra_hide_selectors
      all['extra_hide_selectors'].to_s.gsub(/[<>{}@\\]/, '').split(/[\n,]/).map(&:strip).reject(&:empty?)
    end
  end
end
