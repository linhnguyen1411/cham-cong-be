# app/controllers/api/v1/work_shifts_controller.rb
module Api
  module V1
    class WorkShiftsController < ApplicationController
      before_action :authorize_request
      before_action :set_work_shift, only: [:show, :update, :destroy]
      
      # GET /api/v1/work_shifts
      def index
        @work_shifts = WorkShift.all

        # Scope theo vai trò: branch_admin chỉ xem ca của chi nhánh mình
        if @current_user&.branch_admin? && !@current_user&.super_admin?
          branch_ids = @current_user.managed_branches.pluck(:id)
          branch_ids = [@current_user.branch_id].compact if branch_ids.empty? && @current_user.branch_id.present?
          if branch_ids.any?
            dept_ids_in_branch = Department.where(branch_id: branch_ids).pluck(:id)
            # Ca gắn department HOẶC ca gắn position (position -> department -> branch)
            @work_shifts = @work_shifts.where(
              "department_id IN (?) OR position_id IN (SELECT id FROM positions WHERE department_id IN (?))",
              dept_ids_in_branch, dept_ids_in_branch
            )
          else
            @work_shifts = @work_shifts.none
          end
        elsif @current_user&.department_manager? && !@current_user&.is_admin?
          dept_ids = @current_user.managed_departments.pluck(:id)
          @work_shifts = @work_shifts.where(department_id: dept_ids) if dept_ids.any?
        elsif @current_user&.position_manager? && !@current_user&.is_admin?
          pos_ids = @current_user.managed_positions.pluck(:id)
          @work_shifts = @work_shifts.where(position_id: pos_ids) if pos_ids.any?
        end
        
        # Filter by department if provided
        @work_shifts = @work_shifts.where(department_id: params[:department_id]) if params[:department_id].present?
        
        # Filter by position if provided
        @work_shifts = @work_shifts.where(position_id: params[:position_id]) if params[:position_id].present?
        
        render json: @work_shifts.map { |s|
          s.as_json.merge(
            department_name: s.department&.name,
            position_name: s.position&.name,
            position_id: s.position_id
          )
        }
      end
      
      def show
        render json: @work_shift.as_json.merge(
          department_name: @work_shift.department&.name,
          position_name: @work_shift.position&.name,
          position_id: @work_shift.position_id
        )
      end
      
      # POST /api/v1/work_shifts
      def create
        return unless require_permission!('work_shifts', 'create')

        dept_id = work_shift_params[:department_id].presence

        # Super admin & branch admin: bắt buộc chọn khối (department) khi tạo
        if @current_user&.super_admin? || @current_user&.branch_admin?
          unless dept_id.present?
            return render json: { error: 'Vui lòng chọn chi nhánh và khối khi tạo ca làm việc' }, status: :unprocessable_entity
          end
          dept = Department.find_by(id: dept_id)
          unless dept
            return render json: { error: 'Khối không tồn tại' }, status: :unprocessable_entity
          end
          if @current_user&.branch_admin? && !@current_user&.super_admin?
            branch_ids = @current_user.managed_branches.pluck(:id)
            branch_ids = [@current_user.branch_id].compact if branch_ids.empty? && @current_user.branch_id.present?
            unless branch_ids.include?(dept.branch_id)
              return render json: { error: 'Bạn chỉ có thể tạo ca trong khối thuộc chi nhánh mình quản lý' }, status: :forbidden
            end
          end
        end

        # Department manager: chỉ tạo trong khối mình quản lý
        if @current_user&.department_manager? && !@current_user&.is_admin?
          unless dept_id.present? && @current_user&.managed_departments.exists?(dept_id)
            return render json: { error: 'Bạn chỉ có thể tạo ca làm việc trong khối mà bạn quản lý' }, status: :forbidden
          end
        end
        
        @work_shift = WorkShift.new(work_shift_params)
        
        if @work_shift.save
          render json: @work_shift.as_json.merge(
            department_name: @work_shift.department&.name,
            position_name: @work_shift.position&.name,
            position_id: @work_shift.position_id
          ), status: :created
        else
          render json: { errors: @work_shift.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PATCH/PUT /api/v1/work_shifts/:id
      def update
        return unless require_permission!('work_shifts', 'update')

        unless can_manage_work_shift?(@work_shift)
          return render_forbidden('Bạn không có quyền sửa ca làm việc này')
        end
        
        if @work_shift.update(work_shift_params)
          render json: @work_shift.as_json.merge(
            department_name: @work_shift.department&.name,
            position_name: @work_shift.position&.name,
            position_id: @work_shift.position_id
          )
        else
          render json: { errors: @work_shift.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/work_shifts/:id
      def destroy
        return unless require_permission!('work_shifts', 'delete')

        unless can_manage_work_shift?(@work_shift)
          return render_forbidden('Bạn không có quyền xóa ca làm việc này')
        end
        
        @work_shift.destroy
        head :no_content
      end
      
      private

      def can_manage_work_shift?(shift)
        return true if @current_user&.super_admin?
        return false if shift.department_id.blank?  # Ca chung (không gắn khối) chỉ super_admin xóa được
        if @current_user&.branch_admin?
          branch_ids = @current_user.managed_branches.pluck(:id)
          branch_ids = [@current_user.branch_id].compact if branch_ids.empty? && @current_user.branch_id.present?
          dept = shift.department
          return dept && branch_ids.include?(dept.branch_id)
        end
        if @current_user&.department_manager?
          return @current_user.managed_departments.exists?(shift.department_id)
        end
        false
      end
      
      def set_work_shift
        @work_shift = WorkShift.find(params[:id])
      end
      
      def work_shift_params
        params.require(:work_shift).permit(:name, :start_time, :end_time, :late_threshold, :department_id, :position_id)
      end
    end
  end
end