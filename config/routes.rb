# frozen_string_literal: true

# Picture of a user (for everyone who may see that user)
get 'avatar_control/:id', to: 'avatar_control#show', as: 'avatar_control_image', constraints: { id: /\d+/ }

# Own avatar
get 'my/avatar_control', to: 'avatar_control#edit', as: 'my_avatar_control'
post 'my/avatar_control', to: 'avatar_control#update'

# Avatar of any user (administrators)
get 'users/:user_id/avatar_control', to: 'avatar_control#edit', as: 'user_avatar_control',
                                     constraints: { user_id: /\d+/ }
post 'users/:user_id/avatar_control', to: 'avatar_control#update', constraints: { user_id: /\d+/ }
