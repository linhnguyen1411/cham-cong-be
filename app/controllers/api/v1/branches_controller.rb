module Api
  module V1
    class BranchesController < ApplicationController
      before_action :authorize_request
      before_action :check_admin_permission, except: [:index, :show]
      before_action :set_branch, only: [:show, :update, :destroy, :assign_manager, :remove_manager]

      # GET /api/v1/branches
      def index
        @branches = Branch.all.order(:name)
        render json: @branches.map { |b|
          b.as_json.merge(
            users_count: b.users.count,
            manager_id: b.manager_id,
            manager_name: b.manager&.full_name,
            manager_username: b.manager&.username
          )
        }, status: :ok
      end

      # GET /api/v1/branches/:id
      def show
        render json: @branch.as_json.merge(
          users_count: @branch.users.count,
          manager_id: @branch.manager_id,
          manager_name: @branch.manager&.full_name,
          manager_username: @branch.manager&.username,
          users: @branch.users.map { |u| { id: u.id, full_name: u.full_name, role: u.role } }
        ), status: :ok
      end

      # POST /api/v1/branches
      def create
        # Validate manager_id nếu được cung cấp
        if branch_params[:manager_id].present?
          manager = User.find_by(id: branch_params[:manager_id])
          unless manager
            return render json: { error: 'Không tìm thấy quản lý' }, status: :not_found
          end
        end
        
        @branch = Branch.new(branch_params)
        if @branch.save
          render json: @branch.as_json.merge(
            manager_id: @branch.manager_id,
            manager_name: @branch.manager&.full_name,
            manager_username: @branch.manager&.username
          ), status: :created
        else
          render json: @branch.errors, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/branches/:id
      def update
        # Validate manager_id nếu được cung cấp
        if branch_params[:manager_id].present?
          manager = User.find_by(id: branch_params[:manager_id])
          unless manager
            return render json: { error: 'Không tìm thấy quản lý' }, status: :not_found
          end
        end
        
        if @branch.update(branch_params)
          render json: @branch.as_json.merge(
            manager_id: @branch.manager_id,
            manager_name: @branch.manager&.full_name,
            manager_username: @branch.manager&.username
          ), status: :ok
        else
          render json: @branch.errors, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/branches/:id/assign_manager
      def assign_manager
        manager_id = params[:manager_id]
        
        if manager_id.blank?
          return render json: { error: 'Thiếu manager_id' }, status: :bad_request
        end
        
        manager = User.find_by(id: manager_id)
        unless manager
          return render json: { error: 'Không tìm thấy quản lý' }, status: :not_found
        end
        
        @branch.manager_id = manager_id
        if @branch.save
          render json: @branch.as_json.merge(
            manager_id: @branch.manager_id,
            manager_name: @branch.manager&.full_name,
            manager_username: @branch.manager&.username
          ), status: :ok
        else
          render json: @branch.errors, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/branches/:id/remove_manager
      def remove_manager
        @branch.manager_id = nil
        if @branch.save
          render json: @branch.as_json.merge(
            manager_id: nil,
            manager_name: nil,
            manager_username: nil
          ), status: :ok
        else
          render json: @branch.errors, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/branches/:id
      def destroy
        if @branch.users.any?
          render json: { error: 'Không thể xóa chi nhánh có nhân viên' }, status: :unprocessable_entity
        else
          @branch.destroy
          render json: { message: 'Đã xóa chi nhánh' }, status: :ok
        end
      end

      private

      def set_branch
        @branch = Branch.find(params[:id])
      end

      def branch_params
        params.require(:branch).permit(:name, :address, :description, :manager_id)
      end

      def check_admin_permission
        unless require_admin!
          return
        end
      end
    end
  end
end
