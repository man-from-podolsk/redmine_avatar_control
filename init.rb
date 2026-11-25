# frozen_string_literal: true

# Avatar Control: one place to decide which avatar a user has and where avatars are shown.
#
#   My account -> Avatar            upload a picture, pick a preset, use Redmine's default or no avatar,
#                                   and optionally hide all avatars for yourself
#   Administration -> Users         the same page for any user (administrators)
#   Administration -> Plugins       global mode (show all / only chosen ones / hide all),
#                                   projects without avatars, what users may choose
#
# Replaces the redmine_avatars plugin; its pictures are imported with
#   bundle exec rake redmine:avatar_control:import_redmine_avatars RAILS_ENV=production

Redmine::Plugin.register :redmine_avatar_control do
  name 'Avatar Control'
  author 'man-from-podolsk'
  author_url 'https://github.com/man-from-podolsk'
  description 'Own, preset or no avatars; hide avatars globally, when not set, per project or for yourself.'
  version '1.1.0'
  url 'https://github.com/man-from-podolsk/redmine_avatar_control'
  requires_redmine version_or_higher: '6.1.0'

  settings default: RedmineAvatarControl::Settings::DEFAULTS.dup,
           partial: 'settings/avatar_control_settings'
end

AvatarsHelper.prepend(RedmineAvatarControl::AvatarsHelperPatch) unless AvatarsHelper < RedmineAvatarControl::AvatarsHelperPatch
User.include(RedmineAvatarControl::UserPatch) unless User < RedmineAvatarControl::UserPatch
RedmineAvatarControl::Hooks
