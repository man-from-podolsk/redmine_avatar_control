# frozen_string_literal: true

module RedmineAvatarControl
  # Removes the uploaded picture when the user is deleted
  module UserPatch
    def self.included(base)
      base.after_destroy :avatar_control_remove_files
    end

    private

    def avatar_control_remove_files
      Storage.new(self).remove_files
    rescue Storage::Error => e
      Rails.logger.warn("Avatar Control: could not remove the picture of user #{id}: #{e.message}")
    end
  end
end
