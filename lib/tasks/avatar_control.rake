# frozen_string_literal: true

namespace :redmine do
  namespace :avatar_control do
    desc <<~DESC
      Imports the pictures uploaded with the redmine_avatars plugin.
      Reads <attachments_storage_path>/redmine_avatars and the users' preferences; the old files are left in place.
      Users who already have a picture in Avatar Control are skipped unless FORCE=1.
      DRY_RUN=1 only lists what would be imported.
    DESC
    task import_redmine_avatars: :environment do
      source_dir = File.join(Attachment.storage_path, 'redmine_avatars')
      force = ENV['FORCE'] == '1'
      dry_run = ENV['DRY_RUN'] == '1'
      imported = skipped = missing = 0

      UserPreference.find_each do |pref|
        meta = pref[:avatar]
        next unless meta.is_a?(Hash) && meta['filename'].present?

        user = User.find_by(id: pref.user_id)
        next unless user

        file = File.join(source_dir, File.basename(meta['filename'].to_s))
        unless File.file?(file)
          missing += 1
          puts "  #{user.login}: file not found (#{file})"
          next
        end

        choice = RedmineAvatarControl::Choice.new(user)
        if choice.filename.present? && !force
          skipped += 1
          puts "  #{user.login}: already has a picture, skipped"
          next
        end

        if dry_run
          puts "  #{user.login}: would import #{file}"
        else
          stored = RedmineAvatarControl::Storage.new(user).import_png!(File.binread(file))
          choice.update!(stored.merge('source' => 'upload'))
          puts "  #{user.login}: imported"
        end
        imported += 1
      end

      puts "#{dry_run ? 'Would import' : 'Imported'}: #{imported}, skipped: #{skipped}, files missing: #{missing}"
    end
  end
end
