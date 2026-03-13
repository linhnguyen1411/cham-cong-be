# app/controllers/api/v1/work_sessions_controller.rb
module Api
  module V1
    class WorkSessionsController < ApplicationController
      before_action :authorize_request, except: []
      
      # GET /api/v1/work_sessions
      def index
        if params[:user_id].present?
          # Kiểm tra quyền: Admin hoặc position/department manager của user đó
          target_user = User.find_by(id: params[:user_id])
          unless @current_user&.is_admin? || @current_user&.can_view_user?(target_user) || @current_user&.id == params[:user_id].to_i
            return render json: { error: 'Bạn không có quyền xem dữ liệu này' }, status: :forbidden
          end
          @sessions = WorkSession.where(user_id: params[:user_id]).order(start_time: :desc)
        elsif @current_user&.is_admin? || @current_user&.super_admin?
          # Admin/Super Admin xem tất cả
          @sessions = WorkSession.all.order(start_time: :desc)
        elsif @current_user&.position_manager? || @current_user&.department_manager?
          # Position/Department manager xem của nhân viên trong team
          manageable_ids = @current_user.manageable_user_ids
          @sessions = WorkSession.where(user_id: manageable_ids).order(start_time: :desc)
        else
          # Staff chỉ xem của mình
          @sessions = WorkSession.where(user_id: @current_user.id).order(start_time: :desc)
        end
        
        render json: @sessions.map { |s| 
          {
            id: s.id,
            user_id: s.user_id,
            user_name: s.user&.full_name || 'Unknown',
            start_time: s.start_time,
            end_time: s.end_time,
            duration_minutes: s.duration_minutes,
            date: s.date,
            work_shift_id: s.work_shift_id,
            shift_name: s.work_shift&.name,
            shift_registration_id: s.respond_to?(:shift_registration_id) ? s.shift_registration_id : nil,
            is_on_time: s.is_on_time,
            minutes_late: s.minutes_late,
            is_early_checkout: s.is_early_checkout,
            minutes_before_end: s.minutes_before_end,
            forgot_checkout: s.respond_to?(:forgot_checkout) ? s.forgot_checkout : false,
            work_summary: s.work_summary,
            challenges: s.challenges,
            suggestions: s.suggestions,
            notes: s.notes
          }
        }
      end
      
      def show
        @session = WorkSession.find_by(id: params[:id])
        render json: @session, status: :ok
      end
      # POST /api/v1/work_sessions
      # Check-in
      def create
        # Ownership: chỉ được check-in cho chính mình, trừ khi admin/manager
        target_user_id = params[:work_session][:user_id]
        if target_user_id.present? && target_user_id.to_s != @current_user.id.to_s
          target_user = User.find_by(id: target_user_id)
          unless @current_user&.is_admin? || @current_user&.can_manage_user?(target_user)
            return render_forbidden('Bạn không có quyền chấm công cho người khác')
          end
        end

        # Chỉ kiểm tra các session thực sự đang active (không phải forgot_checkout)
        active_session = WorkSession.where(
          user_id: params[:work_session][:user_id],
          end_time: nil,
          forgot_checkout: false
        ).first
        
        if active_session
          return render json: { message: 'Đang có ca làm việc chưa kết thúc' }, status: :bad_request
        end

        # Kiểm tra IP whitelist
        ip_check_result = check_ip_allowed
        unless ip_check_result[:allowed]
          return render json: { message: ip_check_result[:message] }, status: :forbidden
        end

        @session = WorkSession.new(session_params)
        @session.start_time ||= Time.current
        @session.date = @session.start_time.to_date
        @session.ip_address = request.remote_ip
        
        if @session.save
          render json: @session, status: :created
        else
          render json: @session.errors, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/work_sessions/:id
      # Check-out
      def update
        @session = WorkSession.find(params[:id])

        # Ownership: chỉ được check-out session của mình, trừ khi admin/manager
        unless @current_user&.id == @session.user_id || @current_user&.is_admin? || @current_user&.can_manage_user?(@session.user)
          return render_forbidden('Bạn không có quyền kết thúc ca làm việc của người khác')
        end

        if @session.end_time.present?
          return render json: { message: 'Ca làm việc này đã kết thúc rồi' }, status: :bad_request
        end
        
        # Kiểm tra IP whitelist
        ip_check_result = check_ip_allowed
        unless ip_check_result[:allowed]
          return render json: { message: ip_check_result[:message] }, status: :forbidden
        end
        
        params_to_update = {}

        params_to_update[:end_time] = Time.current if @session.end_time.nil?
        params_to_update[:duration_minutes] = ((params_to_update[:end_time] - @session.start_time) / 60).to_i
        params_to_update.merge!(session_params.slice(:work_summary, :challenges, :suggestions, :notes).compact)
        if @session.update(params_to_update)
          render json: @session
        else
          render json: @session.errors, status: :unprocessable_entity
        end
      end

      # POST /api/v1/work_sessions/:id/admin_update
      # Admin/Manager chỉnh sửa work session (cho phép sửa start_time, end_time, notes, etc.)
      def admin_update
        @session = WorkSession.find(params[:id])
        session_user = @session.user
        
        # Kiểm tra quyền: Admin hoặc manager có quyền quản lý user này
        unless @current_user&.is_admin? || @current_user&.can_manage_user?(session_user) || @current_user&.can_view_user?(session_user)
          return render json: { error: 'Bạn không có quyền chỉnh sửa ca làm việc này' }, status: :forbidden
        end
        
        update_params = admin_session_params.to_h.compact
        
        # Tính lại duration nếu có thay đổi start_time hoặc end_time
        if update_params[:start_time].present? || update_params[:end_time].present?
          start_time = update_params[:start_time] ? Time.parse(update_params[:start_time]) : @session.start_time
          end_time = update_params[:end_time] ? (update_params[:end_time].present? ? Time.parse(update_params[:end_time]) : nil) : @session.end_time
          
          if start_time && end_time
            update_params[:duration_minutes] = ((end_time - start_time) / 60).to_i
            update_params[:date] = start_time.to_date
          end
        end
        
        if @session.update(update_params)
          render json: {
            id: @session.id,
            user_id: @session.user_id,
            user_name: @session.user&.full_name || 'Unknown',
            start_time: @session.start_time,
            end_time: @session.end_time,
            duration_minutes: @session.duration_minutes,
            date: @session.date,
            work_shift_id: @session.work_shift_id,
            shift_name: @session.work_shift&.name,
            is_on_time: @session.is_on_time,
            minutes_late: @session.minutes_late,
            is_early_checkout: @session.is_early_checkout,
            minutes_before_end: @session.minutes_before_end,
            forgot_checkout: @session.forgot_checkout || false,
            work_summary: @session.work_summary,
            challenges: @session.challenges,
            suggestions: @session.suggestions,
            notes: @session.notes
          }, status: :ok
        else
          render json: { errors: @session.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/work_sessions/active
      def active
        # Lấy param user_id từ query string hoặc từ current_user
        uid = params[:user_id] 
        @session = WorkSession.where(user_id: uid, end_time: nil, forgot_checkout: false).last
        
        if @session
          render json: @session
        else
          render json: nil # Trả về null để frontend biết không có active session
        end
      end
      
      # POST /api/v1/work_sessions/process_forgot_checkouts
      # Được gọi bởi cron job hoặc manual trigger
      def process_forgot_checkouts
        WorkSession.process_forgot_checkouts!
        
        forgot_count = WorkSession.where(forgot_checkout: true).count
        render json: { 
          message: 'Đã xử lý các phiên quên checkout',
          forgot_checkout_count: forgot_count
        }
      end

      private

      def session_params
        params.require(:work_session).permit(:user_id, :start_time, :end_time, :work_summary, :challenges, :suggestions, :notes) 
      end

      def admin_session_params
        params.require(:work_session).permit(:start_time, :end_time, :work_summary, :challenges, :suggestions, :notes)
      end

      def check_ip_allowed
        setting = AppSetting.current
        return { allowed: true } unless setting.require_ip_check

        client_ip = request.remote_ip
        allowed_ips = setting.allowed_ips || []

        if allowed_ips.empty?
          return { allowed: false, message: 'Chưa cấu hình địa chỉ IP được phép chấm công' }
        end

        if allowed_ips.include?(client_ip)
          { allowed: true }
        else
          { allowed: false, message: "Địa chỉ IP #{client_ip} không được phép chấm công. Vui lòng liên hệ quản trị viên." }
        end
      end
    end
  end
end