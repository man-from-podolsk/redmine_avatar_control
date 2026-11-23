# frozen_string_literal: true

require 'cgi'
require 'digest'

module RedmineAvatarControl
  # Preset avatars. The local ones are drawn here as SVG and never leave the server; the Gravatar ones
  # are the "Default Gravatar image" styles, fetched from the avatar server with a random hash
  # (no e-mail address is sent) and only when the administrator allows them.
  module Presets
    LOCAL = %w[initials identicon pixel color silhouette].freeze
    GRAVATAR = %w[monsterid wavatar robohash retro].freeze

    PALETTE = %w[#e8590c #2f9e44 #1971c2 #9c36b5 #c2255c #0c8599 #f08c00 #5f3dc4].freeze
    BACKGROUND = '#f1f3f5'

    module_function

    def all
      LOCAL + GRAVATAR
    end

    def gravatar?(style)
      GRAVATAR.include?(style.to_s)
    end

    def available
      return [] unless Settings.flag?('allow_presets')

      Settings.flag?('allow_gravatar_presets') ? all : LOCAL
    end

    def allowed?(style)
      available.include?(style.to_s)
    end

    def bytes(seed)
      Digest::SHA256.digest(seed.to_s).bytes
    end

    def color(seed, offset = 0)
      PALETTE[bytes(seed)[offset] % PALETTE.size]
    end

    # Hash used for the Gravatar styles: derived from the seed, not from the e-mail address
    def gravatar_hash(seed)
      Digest::SHA256.hexdigest("redmine-avatar-control:#{seed}")
    end

    def gravatar_url(style, seed, size)
      base = Redmine::Configuration['avatar_server_url'].to_s.chomp('/')
      "#{base}/avatar/#{gravatar_hash(seed)}?s=#{size.to_i * 2}&d=#{CGI.escape(style.to_s)}&f=y"
    end

    # SVG markup for a local preset (not "initials", which Redmine draws itself)
    def svg(style, seed, size:, title:, css_class:)
      view, body =
        case style.to_s
        when 'identicon' then identicon(seed)
        when 'pixel' then pixel(seed)
        when 'color' then [1, %(<rect width="1" height="1" fill="#{color(seed)}"/>)]
        when 'silhouette' then silhouette(seed)
        else return ''
        end
      title = CGI.escapeHTML(title.to_s)
      %(<svg xmlns="http://www.w3.org/2000/svg" class="#{CGI.escapeHTML(css_class.to_s)}" width="#{size.to_i}" ) +
        %(height="#{size.to_i}" viewBox="0 0 #{view} #{view}" shape-rendering="crispEdges" role="img" ) +
        %(aria-label="#{title}"><title>#{title}</title>#{body}</svg>)
    end

    # 5 x 5 mirrored blocks in one colour, as Gravatar's identicons
    def identicon(seed)
      b = bytes(seed)
      fill = color(seed, 31)
      cells = []
      5.times do |row|
        3.times do |col|
          next unless b[row * 3 + col].odd?

          [col, 4 - col].uniq.each { |x| cells << %(<rect x="#{x + 1}" y="#{row + 1}" width="1" height="1"/>) }
        end
      end
      [7, %(<rect width="7" height="7" fill="#{BACKGROUND}"/><g fill="#{fill}">#{cells.join}</g>)]
    end

    # 8 x 8 mirrored pixel face in two colours
    def pixel(seed)
      b = bytes(seed)
      first = color(seed, 30)
      second = color(seed, 29)
      second = PALETTE[(PALETTE.index(first) + 3) % PALETTE.size] if second == first
      cells = []
      8.times do |row|
        4.times do |col|
          value = b[row * 4 + col] % 3
          next if value.zero?

          fill = value == 1 ? first : second
          [col, 7 - col].each { |x| cells << %(<rect x="#{x}" y="#{row}" width="1" height="1" fill="#{fill}"/>) }
        end
      end
      [8, %(<rect width="8" height="8" fill="#{BACKGROUND}"/>#{cells.join})]
    end

    # A neutral head-and-shoulders figure on a coloured background
    def silhouette(seed)
      [64, %(<rect width="64" height="64" fill="#{color(seed, 28)}"/>) +
        %(<circle cx="32" cy="25" r="12" fill="#ffffff" fill-opacity="0.9"/>) +
        %(<path d="M10 64c0-14 10-24 22-24s22 10 22 24z" fill="#ffffff" fill-opacity="0.9"/>)]
    end
  end
end
