module Api
  module V1
    class RolesController < ApplicationController
      before_action :authorize_request
      before_action :check_super_admin, except: [:index, :show]
      before_action :set_role, only: [:show, :update, :destroy, :assign_permissions]
      
      # GET /api/v1/roles
      def index
        @roles = Role.all.includes(:permissions, :users)
        render json: @roles.map { |r|
          {
            id: r.id,
            name: r.name,
            description: r.description,
            is_system: r.is_system,
            permissions_count: r.permissions.count,
            users_count: r.users.count,
            permissions: r.permissions.map { |p| { id: p.id, name: p.name, resource: p.resource, action: p.action } }
          }
        }, status: :ok
      end
      
      # GET /api/v1/roles/:id
      def show
        render json: {
          id: @role.id,
          name: @role.name,
          description: @role.description,
          is_system: @role.is_system,
          permissions: @role.permissions.map { |p| { id: p.id, name: p.name, resource: p.resource, action: p.action, description: p.description } },
          users_count: @role.users.count
        }, status: :ok
      end
      
      # POST /api/v1/roles
      def create
        @role = Role.new(role_params)
        if @role.save
          render json: @role, status: :created
        else
          render json: { errors: @role.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/roles/:id
      def update
        if @role.is_system
          return render json: { error: 'Không thể sửa role hệ thống' }, status: :unprocessable_entity
        end
        
        if @role.update(role_params.except(:is_system))
          render json: @role, status: :ok
        else
          render json: { errors: @role.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/roles/:id
      def destroy
        if @role.is_system
          return render json: { error: 'Không thể xóa role hệ thống' }, status: :unprocessable_entity
        end
        
        if @role.users.any?
          return render json: { error: 'Không thể xóa role đang có người dùng' }, status: :unprocessable_entity
        end
        
        @role.destroy
        head :no_content
      end
      
      # POST /api/v1/roles/:id/assign_permissions
      def assign_permissions
        permission_ids = params[:permission_ids] || []
        
        @role.permissions = Permission.where(id: permission_ids)
        
        render json: {
          message: 'Đã cập nhật quyền cho role',
          role: @role,
          permissions: @role.permissions.map { |p| { id: p.id, name: p.name, resource: p.resource, action: p.action } }
        }, status: :ok
      end
      
      private
      
      def set_role
        @role = Role.find(params[:id])
      end
      
      def role_params
        params.require(:role).permit(:name, :description, :is_system)
      end
      
      def check_super_admin
        unless @current_user&.super_admin?
          render json: { error: 'Chỉ super admin mới có quyền thực hiện' }, status: :forbidden
        end
      end
    end
  end
end
