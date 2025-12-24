# app/controllers/api/v1/shift_registrations_controller.rb
module Api
  module V1
    class ShiftRegistrationsController < ApplicationController
      before_action :set_registration, only: [:show, :update, :destroy, :approve, :reject]
      
      # GET /api/v1/shift_registrations
      def index
        @registrations = ShiftRegistration.all.includes(:user, :work_shift, :approved_by)
        
        # Filter by user
        @registrations = @registrations.for_user(params[:user_id]) if params[:user_id].present?
        
        # Filter by week
        if params[:week_start].present?
          week_start = Date.parse(params[:week_start])
          @registrations = @registrations.for_week(week_start)
        end
        
        # Filter by status
        @registrations = @registrations.where(status: params[:status]) if params[:status].present?
        
        # Filter by date range
        if params[:start_date].present? && params[:end_date].present?
          @registrations = @registrations.where(work_date: params[:start_date]..params[:end_date])
        end
        
        @registrations = @registrations.order(work_date: :asc, created_at: :desc)
        
        render json: @registrations
      end
      
      # GET /api/v1/shift_registrations/my_registrations
      def my_registrations
        user_id = params[:user_id]
        return render json: { error: 'user_id required' }, status: :bad_request unless user_id
        
        # Lấy đăng ký của tuần hiện tại và tuần tới
        today = Date.current
        current_week_start = today.beginning_of_week(:monday)
        next_week_start = today.next_week(:monday)
        
        @registrations = ShiftRegistration.for_user(user_id)
          .where(week_start: [current_week_start, next_week_start])
          .includes(:work_shift)
          .order(work_date: :asc)
        
        render json: {
          current_week: @registrations.for_week(current_week_start),
          next_week: @registrations.for_week(next_week_start),
          can_register_next_week: can_register_next_week?
        }
      end
      
      # GET /api/v1/shift_registrations/available_shifts
      def available_shifts
        user_id = params[:user_id]
        user = User.find_by(id: user_id)
        
        # Lấy các ca có thể đăng ký (theo department của user hoặc general)
        shifts = if user&.department_id.present?
          WorkShift.where(department_id: [user.department_id, nil])
        else
          WorkShift.where(department_id: nil)
        end
        
        render json: shifts
      end
      
      # GET /api/v1/shift_registrations/pending
      def pending
        @registrations = ShiftRegistration.pending_approval
          .includes(:user, :work_shift)
          .order(work_date: :asc)
        
        render json: @registrations
      end
      
      # GET /api/v1/shift_registrations/:id
      def show
        render json: @registration
      end
      
      # POST /api/v1/shift_registrations
      def create
        @registration = ShiftRegistration.new(registration_params)
        
        if @registration.save
          render json: @registration, status: :created
        else
          render json: { errors: @registration.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/shift_registrations/bulk_create
      def bulk_create
        user_id = params[:user_id]
        registrations_data = params[:registrations] || []
        
        created = []
        errors = []
        
        registrations_data.each do |reg_data|
          begin
            # Parse work_date
            work_date = reg_data[:work_date].is_a?(String) ? Date.parse(reg_data[:work_date]) : reg_data[:work_date]
            
            registration = ShiftRegistration.new(
              user_id: user_id,
              work_shift_id: reg_data[:work_shift_id],
              work_date: work_date,
              note: reg_data[:note]
            )
            
            if registration.save
              created << registration
            else
              errors << { 
                work_date: reg_data[:work_date].to_s, 
                work_shift_id: reg_data[:work_shift_id],
                errors: registration.errors.full_messages,
                error_details: registration.errors.as_json
              }
            end
          rescue => e
            errors << { 
              work_date: reg_data[:work_date].to_s,
              work_shift_id: reg_data[:work_shift_id],
              errors: ["Lỗi: #{e.message}"],
              exception: e.class.name
            }
          end
        end
        
        render json: { 
          created: created, 
          errors: errors,
          success_count: created.count,
          error_count: errors.count
        }
      end
      
      # PATCH /api/v1/shift_registrations/:id
      def update
        if @registration.pending?
          if @registration.update(registration_params.except(:status))
            render json: @registration
          else
            render json: { errors: @registration.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { error: 'Không thể sửa đăng ký đã được duyệt/từ chối' }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/shift_registrations/:id
      def destroy
        if @registration.pending?
          @registration.destroy
          head :no_content
        else
          render json: { error: 'Không thể xóa đăng ký đã được duyệt/từ chối' }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/shift_registrations/:id/approve
      def approve
        admin_user = User.find_by(id: params[:admin_id])
        
        begin
          @registration.approve!(admin_user, params[:note])
          render json: @registration
        rescue => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/shift_registrations/:id/reject
      def reject
        admin_user = User.find_by(id: params[:admin_id])
        
        begin
          @registration.reject!(admin_user, params[:note])
          render json: @registration
        rescue => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/shift_registrations/bulk_approve
      def bulk_approve
        ids = params[:ids] || []
        admin_user = User.find_by(id: params[:admin_id])
        
        approved = []
        errors = []
        
        ShiftRegistration.where(id: ids, status: :pending).find_each do |reg|
          begin
            reg.approve!(admin_user, params[:note])
            approved << reg.id
          rescue => e
            errors << { id: reg.id, error: e.message }
          end
        end
        
        render json: { approved: approved, errors: errors }
      end
      
      private
      
      def set_registration
        @registration = ShiftRegistration.find(params[:id])
      end
      
      def registration_params
        params.require(:shift_registration).permit(:user_id, :work_shift_id, :work_date, :note)
      end
      
      def can_register_next_week?
        # Cho phép đăng ký từ thứ 6 trở đi
        today = Date.current
        today.wday >= 5 || today.wday == 0 # Friday, Saturday, Sunday
      end
    end
  end
end

