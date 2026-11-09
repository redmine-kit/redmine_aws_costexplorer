# frozen_string_literal: true

# The shared entry of the Serverless administration menu (every Redmine
# Serverless plugin draws it; the first one matches).
get 'admin/serverless', to: 'serverless_admin#index'

get 'admin/serverless/costs', to: 'serverless_costs#index', as: 'serverless_costs'
post 'admin/serverless/costs/refresh', to: 'serverless_costs#refresh', as: 'serverless_costs_refresh'
