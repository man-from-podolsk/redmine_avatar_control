# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'stringio'
require 'tmpdir'
require 'timeout'

module RedmineAvatarControl
  # Uploaded pictures. They are kept beside the attachments (<attachments_storage_path>/avatar_control)
  # so that they are backed up with them. Every upload is cropped to a square, scaled to SIZE pixels and
  # saved as PNG without metadata (GPS from phone photos and the like).
  class Storage
    ALLOWED_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
    SIZE = 256

    # Problem with an upload or with the storage directory. reason is a locale key suffix,
    # detail is shown to administrators only.
    class Error < StandardError
      attr_reader :reason, :detail

      def initialize(reason, detail = nil)
        @reason = reason
        @detail = detail
        super([reason, detail].compact.join(': '))
      end
    end

    def self.directory
      File.join(Attachment.storage_path, 'avatar_control')
    end

    def self.convert_bin
      Redmine::Thumbnail::CONVERT_BIN
    end

    def self.convert_available?
      Redmine::Thumbnail.convert_available?
    end

    # Whether the directory exists or can be created, and is writable by Redmine
    def self.writable?
      dir = directory
      return File.writable?(dir) if File.directory?(dir)

      parent = File.dirname(dir)
      File.directory?(parent) && File.writable?(parent)
    end

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def current_path(choice = Choice.new(user))
      name = choice.filename
      return nil if name.blank? || user.id.nil?

      path = File.join(self.class.directory, File.basename(name))
      File.file?(path) ? path : nil
    end

    # Processes an uploaded file and saves it. Returns { 'filename' => ..., 'digest' => ... }.
    def store!(upload, max_bytes)
      raise Error, :blank unless upload.respond_to?(:read) && upload.respond_to?(:original_filename)
      raise Error, :too_large if upload.size.to_i > max_bytes

      data = upload.read.to_s.b
      raise Error, :blank if data.empty?

      content_type = Marcel::MimeType.for(StringIO.new(data), name: upload.original_filename.to_s)
      raise Error, :type unless ALLOWED_TYPES.include?(content_type)
      raise Error, :no_imagemagick unless self.class.convert_available?

      write_png(process(data, content_type))
    end

    # Saves a PNG that is already processed (used when importing from redmine_avatars)
    def import_png!(png)
      write_png(png)
    end

    def remove_files
      return unless user.id

      Dir.glob(File.join(self.class.directory, "#{user.id}-*.png")).each { |file| FileUtils.rm_f(file) }
    rescue SystemCallError => e
      raise Error.new(:storage, "#{self.class.directory}: #{e.message}")
    end

    private

    def write_png(png)
      digest = Digest::SHA256.hexdigest(png)[0, 16]
      filename = "#{user.id}-#{digest}.png"
      FileUtils.mkdir_p(self.class.directory)
      remove_files
      File.binwrite(File.join(self.class.directory, filename), png)
      { 'filename' => filename, 'digest' => digest }
    rescue SystemCallError => e
      raise Error.new(:storage, "#{self.class.directory}: #{e.message}")
    end

    # Square crop from the centre, scaled to SIZE, PNG without metadata. Only the first frame of a GIF.
    def process(data, content_type)
      Dir.mktmpdir('avatar_control') do |dir|
        source = File.join(dir, 'source')
        target = File.join(dir, 'avatar.png')
        File.binwrite(source, data)

        input = content_type == 'image/gif' ? "#{source}[0]" : source
        command = [
          self.class.convert_bin,
          '-limit', 'memory', '256MiB', '-limit', 'map', '512MiB',
          input,
          '-auto-orient', '-strip',
          '-thumbnail', "#{SIZE}x#{SIZE}^",
          '-gravity', 'center', '-extent', "#{SIZE}x#{SIZE}",
          "png:#{target}"
        ]
        raise Error, :processing unless run(command) && File.file?(target)

        File.binread(target)
      end
    end

    # ImageMagick without a shell, with Redmine's thumbnail timeout
    def run(command)
      pid = Process.spawn(*command, out: File::NULL, err: File::NULL)
      Timeout.timeout(Redmine::Configuration['thumbnails_generation_timeout'].to_i.nonzero? || 10) do
        _, status = Process.wait2(pid)
        status.success?
      end
    rescue Timeout::Error
      Process.kill('KILL', pid) rescue nil
      Process.detach(pid)
      false
    rescue SystemCallError
      false
    end
  end
end
