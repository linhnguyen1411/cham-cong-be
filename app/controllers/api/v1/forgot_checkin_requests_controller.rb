module Api
  module V1
    class ForgotCheckinRequestsController < ApplicationController
      before_action :authorize_request
      before_action :set_request, only: [:show, :approve, :reject]

      # GET /api/v1/forgot_checkin_requests
      def index
        if @current_user.admin?
          @requests = ForgotCheckinRequest.all.order(created_at: :desc)
        else
          @requests = ForgotCheckinRequest.where(user_id: @current_user.id).order(created_at: :desc)
        end

        render json: @requests.map { |r|
          {
            id: r.id,
            user_id: r.user_id,
            user_name: r.user&.full_name || 'Unknown',
            request_date: r.request_date,
            request_type: r.request_type,
            request_time: r.request_time,
            reason: r.reason,
            status: r.status,
            approved_by_id: r.approved_by_id,
            approved_by_name: r.approved_by&.full_name,
            approved_at: r.approved_at,
            rejected_reason: r.rejected_reason,
            created_at: r.created_at,
            updated_at: r.updated_at
          }
        }
      end

      # GET /api/v1/forgot_checkin_requests/:id
      def show
        render json: {
          id: @request.id,
          user_id: @request.user_id,
          user_name: @request.user&.full_name || 'Unknown',
          request_date: @request.request_date,
          request_type: @request.request_type,
          request_time: @request.request_time,
          reason: @request.reason,
          status: @request.status,
          approved_by_id: @request.approved_by_id,
          approved_by_name: @request.approved_by&.full_name,
          approved_at: @request.approved_at,
          rejected_reason: @request.rejected_reason,
          created_at: @request.created_at,
          updated_at: @request.updated_at
        }
      end

      # POST /api/v1/forgot_checkin_requests
      def create
        unless @current_user.admin?
          # Kiểm tra giới hạn 3 lần/tháng
          current_month_count = ForgotCheckinRequest
            .where(user_id: @current_user.id)
            .this_month
            .count

          if current_month_count >= 3
            return render json: { 
              error: 'Bạn đã đạt giới hạn 3 lần xin quên checkin/checkout trong tháng này' 
            }, status: :bad_request
          end
        end

        @request = ForgotCheckinRequest.new(request_params)
        @request.user = @current_user
        @request.status = 'pending'

        if @request.save
          render json: @request, status: :created
        else
          render json: { errors: @request.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/forgot_checkin_requests/:id/approve
      def approve
        unless @current_user.admin?
          return render json: { error: 'Chỉ admin mới có quyền duyệt' }, status: :forbidden
        end

        if @request.approve!(@current_user)
          render json: { message: 'Đã duyệt yêu cầu', request: @request }
        else
          render json: { errors: @request.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/forgot_checkin_requests/:id/reject
      def reject
        unless @current_user.admin?
          return render json: { error: 'Chỉ admin mới có quyền từ chối' }, status: :forbidden
        end

        rejected_reason = params[:rejected_reason] || 'Không được duyệt'
        
        if @request.reject!(@current_user, rejected_reason)
          render json: { message: 'Đã từ chối yêu cầu', request: @request }
        else
          render json: { errors: @request.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/forgot_checkin_requests/my_requests
      def my_requests
        @requests = ForgotCheckinRequest.where(user_id: @current_user.id).order(created_at: :desc)
        render json: @requests.map { |r|
          {
            id: r.id,
            user_id: r.user_id,
            user_name: r.user&.full_name || 'Unknown',
            request_date: r.request_date,
            request_type: r.request_type,
            request_time: r.request_time,
            reason: r.reason,
            status: r.status,
            approved_by_id: r.approved_by_id,
            approved_by_name: r.approved_by&.full_name,
            approved_at: r.approved_at,
            rejected_reason: r.rejected_reason,
            created_at: r.created_at,
            updated_at: r.updated_at
          }
        }
      end

      # GET /api/v1/forgot_checkin_requests/pending
      def pending
        unless @current_user.admin?
          return render json: { error: 'Chỉ admin mới có quyền xem' }, status: :forbidden
        end

        @requests = ForgotCheckinRequest.pending.order(created_at: :desc)
        render json: @requests.map { |r|
          {
            id: r.id,
            user_id: r.user_id,
            user_name: r.user&.full_name || 'Unknown',
            request_date: r.request_date,
            request_type: r.request_type,
            request_time: r.request_time,
            reason: r.reason,
            status: r.status,
            approved_by_id: r.approved_by_id,
            approved_by_name: r.approved_by&.full_name,
            approved_at: r.approved_at,
            rejected_reason: r.rejected_reason,
            created_at: r.created_at,
            updated_at: r.updated_at
          }
        }
      end

      private

      def set_request
        @request = ForgotCheckinRequest.find(params[:id])
      end

      def request_params
        params.require(:forgot_checkin_request).permit(:request_date, :request_type, :reason, :request_time)
      end
    end
  end
end

