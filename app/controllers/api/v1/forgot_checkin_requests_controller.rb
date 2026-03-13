module Api
  module V1
    class ForgotCheckinRequestsController < ApplicationController
      before_action :authorize_request
      before_action :set_request, only: [:show, :approve, :reject]

      # GET /api/v1/forgot_checkin_requests
      def index
        if @current_user&.is_admin?
          # Admin xem tất cả
          @requests = ForgotCheckinRequest.all.order(created_at: :desc)
        elsif @current_user&.position_manager? || @current_user&.department_manager?
          # Position/Department manager chỉ xem requests của nhân viên trong phạm vi quản lý
          manageable_ids = @current_user.manageable_user_ids
          @requests = ForgotCheckinRequest.where(user_id: manageable_ids).order(created_at: :desc)
        else
          # Staff chỉ xem của mình
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
        unless is_admin?
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
        # Kiểm tra quyền: Admin hoặc position/department manager của user trong request
        # Position manager có quyền duyệt (can_view_user), Department manager có quyền quản lý (can_manage_user)
        unless @current_user&.is_admin? || @current_user&.can_view_user?(@request.user)
          return render json: { error: 'Bạn không có quyền duyệt yêu cầu này' }, status: :forbidden
        end

        if @request.approve!(@current_user)
          render json: { message: 'Đã duyệt yêu cầu', request: @request }
        else
          render json: { errors: @request.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/forgot_checkin_requests/:id/reject
      def reject
        # Kiểm tra quyền: Admin hoặc position/department manager của user trong request
        # Position manager có quyền từ chối (can_view_user), Department manager có quyền quản lý (can_manage_user)
        unless @current_user&.is_admin? || @current_user&.can_view_user?(@request.user)
          return render json: { error: 'Bạn không có quyền từ chối yêu cầu này' }, status: :forbidden
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
        if @current_user&.is_admin?
          # Admin xem tất cả pending
          @requests = ForgotCheckinRequest.pending.order(created_at: :desc)
        elsif @current_user&.position_manager? || @current_user&.department_manager?
          # Position/Department manager chỉ xem pending của nhân viên trong phạm vi quản lý
          manageable_ids = @current_user.manageable_user_ids
          @requests = ForgotCheckinRequest.pending
            .where(user_id: manageable_ids)
            .order(created_at: :desc)
        else
          return render json: { error: 'Bạn không có quyền xem danh sách này' }, status: :forbidden
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
      
      # GET /api/v1/forgot_checkin_requests/my_team
      # Position/Department manager xem form xin quên checkin/checkout của nhân viên trong team
      def my_team
        # Nếu là admin, xem tất cả
        if @current_user&.is_admin?
          manageable_ids = User.pluck(:id)
        elsif @current_user&.position_manager? || @current_user&.department_manager?
          # Position/Department manager chỉ xem nhân viên trong phạm vi quản lý
          manageable_ids = @current_user.manageable_user_ids
        else
          # Staff chỉ xem của mình
          manageable_ids = [@current_user.id].compact
        end
        @requests = ForgotCheckinRequest.where(user_id: manageable_ids)
          .order(created_at: :desc)
        
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

