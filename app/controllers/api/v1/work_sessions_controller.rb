# app/controllers/api/v1/work_sessions_controller.rb
module Api
  module V1
    class WorkSessionsController < ApplicationController
      # Giả sử bạn có method current_user từ authentication token
      # before_action :authenticate_user!
      
      # GET /api/v1/work_sessions
      def index
        if params[:user_id].present?
          @sessions = WorkSession.where(user_id: params[:user_id]).order(start_time: :desc)
        else
          # Admin xem tất cả
          @sessions = WorkSession.all.order(start_time: :desc)
        end
        
        render json: @sessions.map { |s| 
          {
            id: s.id,
            user_id: s.user_id,
            start_time: s.start_time,
            end_time: s.end_time,
            duration_minutes: s.duration_minutes,
            date: s.date,
            work_shift_id: s.work_shift_id,
            is_on_time: s.is_on_time,
            minutes_late: s.minutes_late,
            is_early_checkout: s.is_early_checkout,
            minutes_before_end: s.minutes_before_end,
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
        active_session = WorkSession.where(user_id: params[:work_session][:user_id], end_time: nil).first
        
        if active_session
          return render json: { message: 'Đang có ca làm việc chưa kết thúc' }, status: :bad_request
        end

        @session = WorkSession.new(session_params)
        @session.start_time ||= Time.current
        @session.date = @session.start_time.to_date
        
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
        if @session.end_time.present?
           return render json: { message: 'Ca làm việc này đã kết thúc rồi' }, status: :bad_request
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

      # GET /api/v1/work_sessions/active
      def active
        # Lấy param user_id từ query string hoặc từ current_user
        uid = params[:user_id] 
        @session = WorkSession.where(user_id: uid, end_time: nil).last
        
        if @session
          render json: @session
        else
          render json: nil # Trả về null để frontend biết không có active session
        end
      end

      private

      def session_params
        params.require(:work_session).permit(:user_id, :start_time, :end_time, :work_summary, :challenges, :suggestions, :notes) 
      end
    end
  end
end