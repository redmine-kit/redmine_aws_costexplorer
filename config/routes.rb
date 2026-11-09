# frozen_string_literal: true

# The shared entry of the Serverless administration menu (every Redmine
# Serverless plugin draws it; the first one matches).
get 'admin/serverless', to: 'serverless_admin#index'

get 'admin/serverless/costexplorer', to: 'serverless_costexplorer#index', as: 'serverless_costexplorer'
post 'admin/serverless/costexplorer/refresh', to: 'serverless_costexplorer#refresh',
                                              as: 'serverless_costexplorer_refresh'
