# app/controllers/api/v1/positions_controller.rb
module Api
  module V1
    class PositionsController < ApplicationController
      before_action :authorize_request
      before_action :set_position, only: [:show, :update, :destroy, :assign_manager, :remove_manager]
      
      # GET /api/v1/positions
      def index
        @positions = Position.all

        # Scope theo vai trò
        if @current_user&.super_admin?
          # Super admin xem tất cả
        elsif @current_user&.branch_admin?
          # Branch admin chỉ xem vị trí của chi nhánh mình quản lý
          managed_branch_ids = @current_user.managed_branches.pluck(:id)
          managed_branch_ids = [@current_user.branch_id].compact if managed_branch_ids.empty? && @current_user.branch_id.present?
          @positions = @positions.where(branch_id: managed_branch_ids) if managed_branch_ids.present?
        elsif @current_user&.department_manager?
          # Department manager chỉ xem vị trí trong khối mình quản lý
          managed_dept_ids = @current_user.managed_departments.pluck(:id)
          @positions = @positions.where(department_id: managed_dept_ids) if managed_dept_ids.present?
        elsif @current_user&.position_manager?
          # Position manager chỉ xem vị trí mình quản lý
          managed_pos_ids = @current_user.managed_positions.pluck(:id)
          @positions = @positions.where(id: managed_pos_ids) if managed_pos_ids.present?
        elsif @current_user&.department_head?
          # Department head không quản lý → chỉ xem vị trí trong khối của mình
          @positions = @positions.where(department_id: @current_user.department_id) if @current_user.department_id.present?
        end

        # Filter by branch
        @positions = @positions.by_branch(params[:branch_id]) if params[:branch_id].present?
        
        # Filter by department
        @positions = @positions.by_department(params[:department_id]) if params[:department_id].present?
        
        render json: @positions.includes(:branch, :department, :users, :manager).map { |p|
          p.as_json.merge(
            manager_id: p.manager_id,
            manager_name: p.manager&.full_name,
            manager_username: p.manager&.username
          )
        }
      end
      
      # GET /api/v1/positions/:id
      def show
        render json: @position.as_json.merge(
          manager_id: @position.manager_id,
          manager_name: @position.manager&.full_name,
          manager_username: @position.manager&.username
        )
      end
      
      # POST /api/v1/positions
      def create
        return unless require_permission!('positions', 'create')

        # Scope: department manager chỉ có thể tạo position trong khối mà mình quản lý
        if @current_user&.department_manager? && !@current_user&.is_admin?
          department_id = position_params[:department_id]
          unless department_id.present? && @current_user&.can_manage_position?(Position.new(department_id: department_id))
            return render json: { error: 'Bạn chỉ có thể tạo vị trí trong khối mà bạn quản lý' }, status: :forbidden
          end
        end

        # Validate manager_id nếu được cung cấp
        if position_params[:manager_id].present?
          manager = User.find_by(id: position_params[:manager_id])
          unless manager
            return render json: { error: 'Không tìm thấy quản lý' }, status: :not_found
          end
        end

        @position = Position.new(position_params)

        # Branch admin tạo vị trí → tự động gán vào chi nhánh mình quản lý
        if @current_user&.branch_admin? && !@current_user&.super_admin? && @position.branch_id.blank?
          @position.branch_id = @current_user.managed_branches.first&.id
        end
        
        if @position.save
          render json: @position.as_json.merge(
            manager_id: @position.manager_id,
            manager_name: @position.manager&.full_name,
            manager_username: @position.manager&.username
          ), status: :created
        else
          render json: { errors: @position.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/positions/:id
      def update
        # Chỉ admin hoặc department manager có thể sửa position
        unless @current_user&.is_admin? || @current_user&.can_manage_position?(@position)
          return render json: { error: 'Bạn không có quyền sửa vị trí này' }, status: :forbidden
        end
        
        # Validate manager_id nếu được cung cấp
        if position_params[:manager_id].present?
          manager = User.find_by(id: position_params[:manager_id])
          unless manager
            return render json: { error: 'Không tìm thấy quản lý' }, status: :not_found
          end
        end
        
        if @position.update(position_params)
          render json: @position.as_json.merge(
            manager_id: @position.manager_id,
            manager_name: @position.manager&.full_name,
            manager_username: @position.manager&.username
          )
        else
          render json: { errors: @position.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/positions/:id
      def destroy
        # Chỉ admin hoặc department manager có thể xóa position
        unless @current_user&.is_admin? || @current_user&.can_manage_position?(@position)
          return render json: { error: 'Bạn không có quyền xóa vị trí này' }, status: :forbidden
        end
        
        if @position.users.exists?
          render json: { error: 'Không thể xóa vị trí đang có nhân viên' }, status: :unprocessable_entity
        else
          @position.destroy
          head :no_content
        end
      end
      
      # POST /api/v1/positions/:id/assign_manager
      def assign_manager
        # Chỉ admin hoặc department manager có thể assign manager cho position
        unless @current_user&.is_admin? || @current_user&.can_manage_position?(@position)
          return render json: { error: 'Bạn không có quyền assign manager cho vị trí này' }, status: :forbidden
        end
        
        manager_id = params[:manager_id]
        
        if manager_id.blank?
          return render json: { error: 'Thiếu manager_id' }, status: :bad_request
        end
        
        manager = User.find_by(id: manager_id)
        unless manager
          return render json: { error: 'Không tìm thấy quản lý' }, status: :not_found
        end
        
        @position.manager_id = manager_id
        if @position.save
          render json: @position.as_json.merge(
            manager_id: @position.manager_id,
            manager_name: @position.manager&.full_name,
            manager_username: @position.manager&.username
          ), status: :ok
        else
          render json: @position.errors, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/positions/:id/remove_manager
      def remove_manager
        # Chỉ admin hoặc department manager có thể remove manager
        unless @current_user&.is_admin? || @current_user&.can_manage_position?(@position)
          return render json: { error: 'Bạn không có quyền remove manager của vị trí này' }, status: :forbidden
        end
        
        @position.manager_id = nil
        if @position.save
          render json: @position.as_json.merge(
            manager_id: nil,
            manager_name: nil,
            manager_username: nil
          ), status: :ok
        else
          render json: @position.errors, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_position
        @position = Position.find(params[:id])
      end
      
      def position_params
        params.require(:position).permit(:name, :description, :branch_id, :department_id, :level, :manager_id)
      end
    end
  end
end

