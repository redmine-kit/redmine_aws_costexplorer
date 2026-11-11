# frozen_string_literal: true

# The tab under the AWS administration page of redmine_aws, which draws
# admin/aws itself.
get 'admin/aws/costexplorer', to: 'serverless_costexplorer#index', as: 'serverless_costexplorer'
