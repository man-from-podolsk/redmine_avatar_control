# frozen_string_literal: true

module RedmineAvatarControl
  # Prepended to AvatarsHelper (init.rb). Redmine draws every avatar through AvatarsHelper#avatar
  # (issues, history, watchers, activity, news, top menu, Gantt ...), so deciding here covers all of them.
  module AvatarsHelperPatch
    def avatar(user, options = {})
      return ''.html_safe if avatar_control_hidden_here?

      if avatar_control_person?(user)
        choice = avatar_control_choice(user)
        case choice.effective
        when :none then return ''.html_safe
        when :upload, :preset then return avatar_control_tag(user, choice.effective, choice, options)
        end
      end

      # The user has not chosen anything (or is a group / Anonymous)
      return ''.html_safe if Settings.mode == 'only_set'

      super
    end

    # My account: the avatar in the title leads to the avatar page instead of Gravatar
    def avatar_edit_link(user, options = {})
      return super unless avatar_control_person?(user) && user == User.current

      image = avatar(user, { title: l(:avatar_control_change) }.merge(options))
      image.present? ? link_to(image, my_avatar_control_path) : nil
    end

    # Draws the avatar for an explicit source, ignoring where avatars are hidden. Used for the previews
    # on the avatar page. source: :default, :upload or :preset (with style).
    def avatar_control_tag(user, source, choice, options = {}, style: nil)
      options = options.dup
      size = (options.delete(:size) || GravatarHelper::DEFAULT_OPTIONS[:size]).to_i
      title = options[:title].presence || user.name
      css = ['avatar', 'avatar-control', "s#{size}", options[:class]].compact.join(' ')

      case source
      when :upload
        image_tag(avatar_control_image_path(user, v: choice.digest),
                  alt: '', title: title, class: css, width: size, height: size, loading: 'lazy')
      when :preset
        style ||= choice.preset
        if style == 'initials'
          initials_avatar_tag(user, options.merge(size: size, title: title, class: 'avatar avatar-control'))
        elsif Presets.gravatar?(style)
          image_tag(Presets.gravatar_url(style, choice.seed, size),
                    alt: '', title: title, class: css, width: size, height: size, loading: 'lazy')
        else
          Presets.svg(style, choice.seed, size: size, title: title, css_class: css).html_safe
        end
      else
        avatar_control_redmine_default(user, options.merge(size: size, title: title))
      end
    end

    # What Redmine itself would show (initials or Gravatar)
    def avatar_control_redmine_default(user, options)
      options = options.merge(class: ['avatar', options[:class]].compact.join(' '))
      if Setting.gravatar_enabled?
        gravatar_avatar_tag(user, options).to_s.html_safe
      else
        initials_avatar_tag(user, options)
      end
    end

    private

    def avatar_control_person?(user)
      user.is_a?(User) && !user.is_a?(AnonymousUser) && user.id.present?
    end

    def avatar_control_hidden_here?
      project = instance_variable_defined?(:@project) ? @project : nil
      @avatar_control_hidden ||= {}
      key = project.is_a?(Project) ? project.id : nil
      return @avatar_control_hidden[key] if @avatar_control_hidden.key?(key)

      @avatar_control_hidden[key] = Settings.hidden_here?(project, User.current)
    end

    # One Choice per user per page: avoids reading the same preferences for every journal entry
    def avatar_control_choice(user)
      @avatar_control_choices ||= {}
      @avatar_control_choices[user.id] ||= Choice.new(user)
    end
  end
end
