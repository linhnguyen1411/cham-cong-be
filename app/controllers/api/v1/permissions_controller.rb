module Api
  module V1
    class PermissionsController < ApplicationController
      before_action :authorize_request
      before_action :check_super_admin, except: [:index, :show]
      
      # GET /api/v1/permissions
      def index
        @permissions = Permission.all.order(:resource, :action)
        
        # Group by resource
        grouped = @permissions.group_by(&:resource)
        
        render json: {
          permissions: @permissions.map { |p|
            {
              id: p.id,
              name: p.name,
              resource: p.resource,
              action: p.action,
              description: p.description,
              full_name: p.full_name
            }
          },
          grouped: grouped.transform_values { |perms|
            perms.map { |p| { id: p.id, name: p.name, action: p.action, description: p.description } }
          }
        }, status: :ok
      end
      
      # GET /api/v1/permissions/:id
      def show
        @permission = Permission.find(params[:id])
        render json: {
          id: @permission.id,
          name: @permission.name,
          resource: @permission.resource,
          action: @permission.action,
          description: @permission.description,
          roles: @permission.roles.map { |r| { id: r.id, name: r.name } }
        }, status: :ok
      end
      
      private
      
      def check_super_admin
        unless @current_user&.super_admin?
          render json: { error: 'Chỉ super admin mới có quyền thực hiện' }, status: :forbidden
        end
      end
    end
  end
end
