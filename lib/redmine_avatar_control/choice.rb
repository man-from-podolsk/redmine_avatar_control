# frozen_string_literal: true

require 'securerandom'

module RedmineAvatarControl
  # What a user chose as their avatar, kept in their preferences:
  #   pref[:avatar_control] = { 'source' => 'default' | 'upload' | 'preset' | 'none',
  #                             'preset' => 'identicon', 'salt' => 'a1b2c3d4',
  #                             'filename' => '12-0123456789abcdef.png', 'digest' => '0123456789abcdef' }
  #   pref[:avatar_control_hide_all] = '1'   the user does not want to see any avatars
  class Choice
    PREF_KEY = :avatar_control
    HIDE_ALL_KEY = :avatar_control_hide_all
    SOURCES = %w[default upload preset none].freeze

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def data
      value = user.pref[PREF_KEY]
      value.is_a?(Hash) ? value.stringify_keys : {}
    end

    def source
      SOURCES.include?(data['source']) ? data['source'] : 'default'
    end

    def preset
      data['preset'].to_s
    end

    def salt
      data['salt'].to_s
    end

    def digest
      data['digest'].to_s
    end

    def filename
      data['filename'].to_s
    end

    # Seed for the generated presets; changes when the user shuffles them
    def seed
      "#{user.id}:#{salt}"
    end

    def uploaded?
      Storage.new(user).current_path(self).present?
    end

    # What is actually shown, after the administrator's settings and missing files:
    # :upload, :preset, :none or :default
    def effective
      case source
      when 'upload'
        Settings.flag?('allow_upload') && uploaded? ? :upload : :default
      when 'preset'
        Presets.allowed?(preset) ? :preset : :default
      when 'none'
        Settings.flag?('allow_user_none') ? :none : :default
      else
        :default
      end
    end

    def update!(attributes)
      merged = data.merge(attributes.stringify_keys).reject { |_, v| v.nil? }
      user.pref[PREF_KEY] = merged
      user.pref.save!
    end

    def shuffle!
      update!('salt' => SecureRandom.hex(4))
    end

    def hide_all?
      user.pref[HIDE_ALL_KEY].to_s == '1'
    end

    def hide_all=(value)
      user.pref[HIDE_ALL_KEY] = value ? '1' : nil
      user.pref.save!
    end
  end
end
