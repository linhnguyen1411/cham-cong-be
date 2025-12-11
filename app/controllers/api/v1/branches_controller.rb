module Api
  module V1
    class BranchesController < ApplicationController
      before_action :authorize_request
      before_action :check_admin_permission, except: [:index, :show]
      before_action :set_branch, only: [:show, :update, :destroy]

      # GET /api/v1/branches
      def index
        @branches = Branch.all.order(:name)
        render json: @branches, status: :ok
      end

      # GET /api/v1/branches/:id
      def show
        render json: @branch.as_json.merge(
          users_count: @branch.users.count,
          users: @branch.users.map { |u| { id: u.id, full_name: u.full_name, role: u.role } }
        ), status: :ok
      end

      # POST /api/v1/branches
      def create
        @branch = Branch.new(branch_params)
        if @branch.save
          render json: @branch, status: :created
        else
          render json: @branch.errors, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/branches/:id
      def update
        if @branch.update(branch_params)
          render json: @branch, status: :ok
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
        params.require(:branch).permit(:name, :address, :description)
      end

      def check_admin_permission
        unless @current_user.admin?
          render json: { error: 'Chỉ admin mới có quyền thực hiện' }, status: :forbidden
        end
      end
    end
  end
end
