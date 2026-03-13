module Api
  module V1
    class DepartmentsController < ApplicationController
      before_action :authorize_request
      before_action :set_department, only: [:show, :update, :destroy, :assign_manager, :remove_manager]

      # GET /api/v1/departments
      def index
        base = Department.all
        if @current_user&.super_admin?
          # Super admin xem tất cả
        elsif @current_user&.branch_admin?
          branch_ids = @current_user.managed_branches.pluck(:id)
          branch_ids = [@current_user.branch_id].compact if branch_ids.empty? && @current_user.branch_id.present?
          base = branch_ids.any? ? base.where(branch_id: branch_ids) : base.none
        elsif @current_user&.department_head? || @current_user&.department_manager?
          # Department head: chỉ xem các khối mình quản lý
          dept_ids = @current_user.managed_departments.pluck(:id)
          base = base.where(id: dept_ids)
        end
        @departments = base.order(:name)
        render json: @departments.map { |d|
          d.as_json.merge(
            users_count: d.users.count,
            shifts_count: d.work_shifts.count,
            manager_id: d.manager_id,
            manager_name: d.manager&.full_name,
            manager_username: d.manager&.username,
            branch_id: d.branch_id,
            branch_name: d.branch&.name
          )
        }, status: :ok
      end

      # GET /api/v1/departments/:id
      def show
        render json: @department.as_json.merge(
          users_count: @department.users.count,
          shifts_count: @department.work_shifts.count,
          manager_id: @department.manager_id,
          manager_name: @department.manager&.full_name,
          manager_username: @department.manager&.username,
          branch_id: @department.branch_id,
          branch_name: @department.branch&.name,
          work_shifts: @department.work_shifts.map { |s| 
            { id: s.id, name: s.name, start_time: s.start_time, end_time: s.end_time, late_threshold: s.late_threshold }
          }
        ), status: :ok
      end

      # POST /api/v1/departments
      def create
        return unless require_permission!('departments', 'create')
        
        # Validate manager_id nếu được cung cấp
        if department_params[:manager_id].present?
          manager = User.find_by(id: department_params[:manager_id])
          unless manager
            return render json: { error: 'Không tìm thấy quản lý' }, status: :not_found
          end
        end

        create_params = department_params.to_h

        # Branch admin: tu dong gan branch_id theo chi nhanh minh quan ly
        if @current_user&.branch_admin? && !@current_user&.super_admin?
          first_branch = @current_user.managed_branches.first
          create_params[:branch_id] = first_branch&.id if first_branch
        end
        
        @department = Department.new(create_params)
        if @department.save
          render json: @department.as_json.merge(
            manager_id: @department.manager_id,
            manager_name: @department.manager&.full_name,
            manager_username: @department.manager&.username
          ), status: :created
        else
          render json: @department.errors, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/departments/:id
      def update
        # Admin hoặc department manager của khối này có thể update
        unless @current_user&.is_admin? || @current_user&.can_manage_department?(@department)
          return render json: { error: 'Bạn không có quyền sửa khối này' }, status: :forbidden
        end
        
        # Validate manager_id nếu được cung cấp
        if department_params[:manager_id].present?
          manager = User.find_by(id: department_params[:manager_id])
          unless manager
            return render json: { error: 'Không tìm thấy quản lý' }, status: :not_found
          end
        end
        
        if @department.update(department_params)
          render json: @department.as_json.merge(
            manager_id: @department.manager_id,
            manager_name: @department.manager&.full_name,
            manager_username: @department.manager&.username
          ), status: :ok
        else
          render json: @department.errors, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/departments/:id/assign_manager
      def assign_manager
        # Admin hoặc department manager của khối này có thể assign manager
        unless @current_user&.is_admin? || (@current_user&.department_manager? && @current_user&.managed_departments.exists?(@department.id))
          return render json: { error: 'Bạn không có quyền assign manager cho khối này' }, status: :forbidden
        end
        
        manager_id = params[:manager_id]
        
        if manager_id.blank?
          return render json: { error: 'Thiếu manager_id' }, status: :bad_request
        end
        
        manager = User.find_by(id: manager_id)
        unless manager
          return render json: { error: 'Không tìm thấy quản lý' }, status: :not_found
        end
        
        @department.manager_id = manager_id
        if @department.save
          render json: @department.as_json.merge(
            manager_id: @department.manager_id,
            manager_name: @department.manager&.full_name,
            manager_username: @department.manager&.username
          ), status: :ok
        else
          render json: @department.errors, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/departments/:id/remove_manager
      def remove_manager
        # Admin hoặc department manager của khối này có thể remove manager
        unless @current_user&.is_admin? || (@current_user&.department_manager? && @current_user&.managed_departments.exists?(@department.id))
          return render json: { error: 'Bạn không có quyền remove manager của khối này' }, status: :forbidden
        end
        
        @department.manager_id = nil
        if @department.save
          render json: @department.as_json.merge(
            manager_id: nil,
            manager_name: nil,
            manager_username: nil
          ), status: :ok
        else
          render json: @department.errors, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/departments/:id
      def destroy
        unless @current_user&.is_admin? || @current_user&.can_manage_department?(@department)
          return render_forbidden('Bạn không có quyền xóa khối này')
        end

        if @department.users.any?
          render json: { error: 'Không thể xóa khối có nhân viên' }, status: :unprocessable_entity
        else
          @department.destroy
          render json: { message: 'Đã xóa khối' }, status: :ok
        end
      end

      private

      def set_department
        @department = Department.find(params[:id])
      end

      def department_params
        p = params.require(:department).permit(:name, :description, :manager_id, :ip_address, :branch_id, work_days: [])
        # work_days có thể được gửi dưới dạng JSON string từ frontend
        if params[:department][:work_days].is_a?(String)
          begin
            p[:work_days] = JSON.parse(params[:department][:work_days])
          rescue
            p[:work_days] = nil
          end
        end
        p
      end

      def check_admin_permission
        unless require_admin!
          return
        end
      end
    end
  end
end
