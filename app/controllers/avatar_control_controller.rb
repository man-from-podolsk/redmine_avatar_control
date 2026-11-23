# frozen_string_literal: true

class AvatarControlController < ApplicationController
  before_action :require_login, except: :show
  before_action :find_target_user, only: [:edit, :update]

  # GET /avatar_control/:id?v=<digest>
  def show
    user = User.visible.find_by(id: params[:id])
    return render_404 unless user

    choice = RedmineAvatarControl::Choice.new(user)
    path = RedmineAvatarControl::Storage.new(user).current_path(choice)
    # Others see the picture only while it is the chosen avatar; the user and administrators also see it
    # when another option is chosen (preview on the avatar page)
    owner_or_admin = User.current.admin? || User.current.id == user.id
    return render_404 unless path && (choice.effective == :upload || owner_or_admin)

    # A new picture gets a new digest and so a new URL: the old one may be cached for long
    if params[:v].present? && params[:v] == choice.digest
      expires_in 1.year, public: false
    else
      expires_now
    end
    send_file path, type: 'image/png', disposition: 'inline'
  end

  # GET /my/avatar_control, /users/:user_id/avatar_control
  def edit
    @choice = RedmineAvatarControl::Choice.new(@user)
    @settings = RedmineAvatarControl::Settings
    @presets = RedmineAvatarControl::Presets.available
  end

  # POST /my/avatar_control, /users/:user_id/avatar_control
  def update
    choice = RedmineAvatarControl::Choice.new(@user)
    storage = RedmineAvatarControl::Storage.new(@user)

    if params[:shuffle].present?
      choice.shuffle!
      return redirect_to(edit_path)
    end

    if params[:remove_upload] == '1'
      storage.remove_files
      choice.update!('filename' => nil, 'digest' => nil)
      choice.update!('source' => 'default') if choice.source == 'upload'
    end

    apply_choice(choice, storage)

    if RedmineAvatarControl::Settings.flag?('allow_viewer_hide')
      choice.hide_all = params[:hide_all] == '1'
    end

    flash[:notice] = l(:notice_successful_update)
    redirect_to edit_path
  rescue RedmineAvatarControl::Storage::Error => e
    logger&.error("Avatar Control: #{e.message}")
    message = l("avatar_control_error_#{e.reason}", default: l(:avatar_control_error_processing))
    message += " (#{e.detail})" if User.current.admin? && e.detail.present?
    flash[:error] = message
    redirect_to edit_path
  end

  private

  def find_target_user
    if params[:user_id]
      return unless require_admin

      @user = User.find_by(id: params[:user_id])
      render_404 unless @user.is_a?(User)
    else
      @user = User.current
    end
  end

  def edit_path
    @user == User.current && params[:user_id].blank? ? my_avatar_control_path : user_avatar_control_path(@user)
  end

  # choice: "default", "upload", "none" or "preset:<style>"
  def apply_choice(choice, storage)
    selected = params[:choice].to_s
    settings = RedmineAvatarControl::Settings
    file = params[:avatar_file]

    if file.present?
      raise RedmineAvatarControl::Storage::Error, :not_allowed unless settings.flag?('allow_upload')

      meta = storage.store!(file, settings.max_bytes)
      choice.update!(meta.merge('source' => 'upload'))
      return
    end

    case selected
    when 'default'
      choice.update!('source' => 'default')
    when 'upload'
      raise RedmineAvatarControl::Storage::Error, :not_allowed unless settings.flag?('allow_upload')
      raise RedmineAvatarControl::Storage::Error, :blank unless choice.uploaded?

      choice.update!('source' => 'upload')
    when 'none'
      raise RedmineAvatarControl::Storage::Error, :not_allowed unless settings.flag?('allow_user_none')

      choice.update!('source' => 'none')
    when /\Apreset:(\w+)\z/
      style = Regexp.last_match(1)
      raise RedmineAvatarControl::Storage::Error, :not_allowed unless RedmineAvatarControl::Presets.allowed?(style)

      choice.update!('source' => 'preset', 'preset' => style)
    end
  end
end
