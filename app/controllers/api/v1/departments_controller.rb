module Api
  module V1
    class DepartmentsController < ApplicationController
      before_action :authorize_request
      before_action :check_admin_permission, except: [:index, :show]
      before_action :set_department, only: [:show, :update, :destroy]

      # GET /api/v1/departments
      def index
        @departments = Department.all.order(:name)
        render json: @departments.map { |d|
          d.as_json.merge(
            users_count: d.users.count,
            shifts_count: d.work_shifts.count
          )
        }, status: :ok
      end

      # GET /api/v1/departments/:id
      def show
        render json: @department.as_json.merge(
          users_count: @department.users.count,
          shifts_count: @department.work_shifts.count,
          work_shifts: @department.work_shifts.map { |s| 
            { id: s.id, name: s.name, start_time: s.start_time, end_time: s.end_time, late_threshold: s.late_threshold }
          }
        ), status: :ok
      end

      # POST /api/v1/departments
      def create
        @department = Department.new(department_params)
        if @department.save
          render json: @department, status: :created
        else
          render json: @department.errors, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/departments/:id
      def update
        if @department.update(department_params)
          render json: @department, status: :ok
        else
          render json: @department.errors, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/departments/:id
      def destroy
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
        params.require(:department).permit(:name, :description)
      end

      def check_admin_permission
        unless @current_user.admin?
          render json: { error: 'Chỉ admin mới có quyền thực hiện' }, status: :forbidden
        end
      end
    end
  end
end
