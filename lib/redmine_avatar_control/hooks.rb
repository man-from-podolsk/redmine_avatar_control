# frozen_string_literal: true

module RedmineAvatarControl
  # Links to the avatar page and extra CSS where avatars are hidden.
  class Hooks < Redmine::Hook::ViewListener
    # My account: "Avatar" among the actions at the top
    def view_my_account_contextual(context = {})
      link_to(sprite_icon('user', l(:avatar_control_label)), my_avatar_control_path,
              class: 'icon icon-user')
    end

    # Administration -> Users -> edit: a line with the link (administrators only)
    def view_users_form(context = {})
      user = context[:user]
      return '' unless User.current.admin? && user.is_a?(User) && user.persisted?

      content_tag(:p) do
        content_tag(:label, l(:avatar_control_label)) +
          link_to(l(:avatar_control_change), user_avatar_control_path(user))
      end
    end

    # Administration and Plugins pages: a notice for administrators when GitHub has a newer version
    def view_layouts_base_content(context = {})
      controller = context[:controller]
      return '' unless controller && User.current.admin?
      return '' unless RedmineAvatarControl::UpdateCheck.update_admin_page?(controller)

      data = RedmineAvatarControl::UpdateCheck.status
      return '' unless RedmineAvatarControl::UpdateCheck.update_available?(data)

      id = 'redmine_avatar_control_update_notice'
      html = content_tag(:div, RedmineAvatarControl::UpdateCheck.render_notice(self, data, 'avatar_control'), class: 'flash warning', id: id)
      # Moved to the top of the page content
      html + javascript_tag("(function(){var n=document.getElementById('#{id}'),c=document.getElementById('content');" \
                            "if(n&&c){c.insertBefore(n,c.firstChild);}})();")
    end

    # Elements that themes draw on their own (e.g. the Rubylode initials beside assignees) are hidden with
    # CSS wherever avatars are hidden.
    def view_layouts_base_html_head(context = {})
      selectors = Settings.extra_hide_selectors
      return '' if selectors.empty?
      return '' unless Settings.hidden_here?(context[:project], User.current)

      content_tag(:style, "#{selectors.join(', ')} { display: none !important; }".html_safe,
                  id: 'avatar-control-hide')
    end
  end
end
