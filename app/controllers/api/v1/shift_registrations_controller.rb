# app/controllers/api/v1/shift_registrations_controller.rb
module Api
  module V1
    class ShiftRegistrationsController < ApplicationController
      before_action :set_registration, only: [:show, :update, :destroy, :approve, :reject, :admin_update]
      
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
        user = User.find_by(id: user_id)
        
        return render json: { error: 'User not found' }, status: :not_found unless user
        
        # Kiểm tra thời gian đăng ký: chỉ cho phép vào thứ 6 và thứ 7
        unless can_register_next_week?
          today = Date.current
          weekday_name = ['Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'][today.wday]
          return render json: { 
            error: "Chỉ có thể đăng ký ca vào thứ 6 và thứ 7. Hôm nay là #{weekday_name}.",
            error_count: 1,
            success_count: 0
          }, status: :forbidden
        end
        
        # Validate before creating
        validation_errors = validate_bulk_registration(user, registrations_data)
        if validation_errors.any?
          return render json: { 
            errors: validation_errors,
            error_count: validation_errors.count,
            success_count: 0
          }, status: :unprocessable_entity
        end
        
        # All-or-nothing: Dùng transaction để đảm bảo tất cả thành công hoặc tất cả rollback
        created = []
        errors = []
        
        ActiveRecord::Base.transaction do
          # Xóa TẤT CẢ đăng ký pending trong tuần để cho phép đổi đăng ký khi chưa duyệt
          # Lấy week_start từ đăng ký đầu tiên
          first_reg_date = registrations_data.first[:work_date].is_a?(String) ? Date.parse(registrations_data.first[:work_date]) : registrations_data.first[:work_date]
          week_start = first_reg_date.beginning_of_week(:monday)
          
          # Xóa TẤT CẢ pending trong tuần này (cho phép đổi đăng ký)
          ShiftRegistration.where(
            user_id: user_id,
            week_start: week_start,
            status: :pending
          ).delete_all
          
          # Xóa các đăng ký approved/rejected cho các ngày/ca đang được đăng ký lại (nếu có)
          registrations_data.each do |reg_data|
            work_date = reg_data[:work_date].is_a?(String) ? Date.parse(reg_data[:work_date]) : reg_data[:work_date]
            
            # Xóa approved/rejected cho cùng user, date, shift (pending đã xóa ở trên)
            ShiftRegistration.where(
              user_id: user_id,
              work_date: work_date,
              work_shift_id: reg_data[:work_shift_id],
              status: [:approved, :rejected]
            ).delete_all
          end
          
          # Tạo tất cả đăng ký mới - collect tất cả lỗi trước
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
              
              registration.save!
              created << registration
            rescue => e
              # Parse error message để hiển thị rõ ràng hơn
              error_message = e.message
              if e.message.include?('duplicate key') || e.message.include?('already exists') || e.message.include?('idx_shift_reg_user_date_shift')
                error_message = 'Đã có đăng ký cho ca này. Vui lòng tải lại trang.'
              elsif e.message.include?('PG::')
                # Extract meaningful error from PG error
                if e.message.include?('duplicate key')
                  error_message = 'Đã có đăng ký cho ca này. Vui lòng tải lại trang.'
                else
                  error_message = "Lỗi database: #{e.class.name}"
                end
              end
              
              # Collect lỗi, không raise ngay
              errors << { 
                work_date: reg_data[:work_date].to_s, 
                work_shift_id: reg_data[:work_shift_id],
                errors: [error_message],
                exception: e.class.name
              }
            end
          end
          
          # Nếu có bất kỳ lỗi nào, raise để rollback tất cả
          if errors.any?
            raise ActiveRecord::Rollback
          end
        end
        
        # Nếu có lỗi sau transaction, return error (transaction đã rollback)
        if errors.any?
          return render json: { 
            errors: errors,
            error_count: errors.count,
            success_count: 0
          }, status: :unprocessable_entity
        end
        
        render json: { 
          created: created, 
          errors: [],
          success_count: created.count,
          error_count: 0
        }
      end
      
      # PATCH /api/v1/shift_registrations/:id
      def update
        # Cho phép user sửa đăng ký pending của chính họ
        # Hoặc admin có thể sửa bất kỳ đăng ký nào
        if @registration.pending? || current_user&.admin?
          # Admin có thể sửa cả status, user khác chỉ sửa được thông tin đăng ký
          update_params = current_user&.admin? ? registration_params : registration_params.except(:status, :user_id)
          
          if @registration.update(update_params)
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
        # Cho phép user xóa đăng ký pending của chính họ
        # Hoặc admin có thể xóa bất kỳ đăng ký nào
        if @registration.pending? || current_user&.admin?
          @registration.destroy
          head :no_content
        else
          render json: { error: 'Không thể xóa đăng ký đã được duyệt/từ chối' }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/shift_registrations/:id/admin_update
      # Admin có thể sửa đăng ký của nhân viên (kể cả đã approved)
      def admin_update
        unless current_user&.admin?
          return render json: { error: 'Chỉ admin mới có quyền thực hiện' }, status: :forbidden
        end
        
        if @registration.update(admin_registration_params)
          render json: @registration
        else
          render json: { errors: @registration.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/shift_registrations/admin_bulk_update
      # Admin có thể sửa nhiều đăng ký cùng lúc
      def admin_bulk_update
        unless current_user&.admin?
          return render json: { error: 'Chỉ admin mới có quyền thực hiện' }, status: :forbidden
        end
        
        updates = params[:updates] || []
        results = { updated: [], errors: [] }
        
        updates.each do |update_data|
          registration = ShiftRegistration.find_by(id: update_data[:id])
          unless registration
            results[:errors] << { id: update_data[:id], error: 'Không tìm thấy đăng ký' }
            next
          end
          
          if registration.update(
            work_shift_id: update_data[:work_shift_id] || registration.work_shift_id,
            work_date: update_data[:work_date] || registration.work_date,
            note: update_data[:note] || registration.note,
            admin_note: update_data[:admin_note] || registration.admin_note
          )
            results[:updated] << registration.id
          else
            results[:errors] << { id: registration.id, errors: registration.errors.full_messages }
          end
        end
        
        render json: results
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
      # Khi admin từ chối -> xóa luôn đăng ký (không giữ lại lịch sử)
      def reject
        admin_user = User.find_by(id: params[:admin_id])
        
        begin
          registration_id = @registration.id
          @registration.destroy
          render json: { 
            message: 'Đã từ chối và xóa đăng ký',
            id: registration_id
          }, status: :ok
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
        params.require(:shift_registration).permit(:user_id, :work_shift_id, :work_date, :note, :status)
      end
      
      def admin_registration_params
        params.require(:shift_registration).permit(:user_id, :work_shift_id, :work_date, :note, :admin_note, :status)
      end
      
      def current_user
        @current_user ||= begin
          header = request.headers['Authorization']
          return nil unless header
          
          token = header.split(' ').last
          decoded = JsonWebToken.decode(token)
          return nil unless decoded
          
          User.find_by(id: decoded[:user_id])
        rescue
          nil
        end
      end
      
      def can_register_next_week?
        # Chỉ cho phép đăng ký vào thứ 6 (wday = 5) và thứ 7 (wday = 6)
        today = Date.current
        today.wday == 5 || today.wday == 6 # Friday (5) or Saturday (6)
      end
      
      def validate_bulk_registration(user, registrations_data)
        errors = []
        
        # Parse dates and group by week
        parsed_regs = registrations_data.map do |reg_data|
          work_date = reg_data[:work_date].is_a?(String) ? Date.parse(reg_data[:work_date]) : reg_data[:work_date]
          { work_date: work_date, work_shift_id: reg_data[:work_shift_id].to_i }
        end
        
        # Get all shifts to identify morning/afternoon
        all_shifts = WorkShift.all.index_by(&:id)
        morning_shift_id = all_shifts.values.find { |s| s.name.downcase.include?('sáng') || (s.start_time.present? && s.start_time < '12:00') }&.id
        afternoon_shift_id = all_shifts.values.find { |s| s.name.downcase.include?('chiều') || (s.start_time.present? && s.start_time >= '12:00' && s.start_time < '18:00') }&.id
        
        # Group by week
        weeks = parsed_regs.group_by { |r| r[:work_date].beginning_of_week(:monday) }
        
        weeks.each do |week_start, week_regs|
          week_dates = (week_start..(week_start + 6.days)).to_a
          
          # Calculate expected shifts based on work_schedule_type (chỉ các ca bắt buộc, không tính tăng ca)
          expected_shifts_by_date = week_dates.map do |date|
            case user.work_schedule_type
            when 'both_shifts'
              [morning_shift_id, afternoon_shift_id].compact
            when 'morning_only'
              morning_shift_id ? [morning_shift_id] : []
            when 'afternoon_only'
              afternoon_shift_id ? [afternoon_shift_id] : []
            else
              [morning_shift_id, afternoon_shift_id].compact
            end
          end.flatten.compact
          
          # Get existing APPROVED registrations for this week (không lấy pending vì sẽ bị xóa)
          # Pending sẽ bị xóa trước khi tạo mới, nên không cần validate với pending cũ
          existing_approved_regs = ShiftRegistration
            .where(user_id: user.id, week_start: week_start, status: :approved)
            .pluck(:work_date, :work_shift_id)
            .map { |date, shift_id| { work_date: date, work_shift_id: shift_id } }
          
          # Combine existing APPROVED and new registrations (pending sẽ bị xóa)
          all_regs = (existing_approved_regs + week_regs).uniq { |r| [r[:work_date], r[:work_shift_id]] }
          
          # Chỉ đếm các ca bắt buộc (không tính tăng ca)
          # Tăng ca: morning_only đăng ký afternoon hoặc afternoon_only đăng ký morning
          registered_required_shifts = all_regs.select do |r|
            shift_id = r[:work_shift_id]
            case user.work_schedule_type
            when 'both_shifts'
              shift_id == morning_shift_id || shift_id == afternoon_shift_id
            when 'morning_only'
              shift_id == morning_shift_id
            when 'afternoon_only'
              shift_id == afternoon_shift_id
            else
              true
            end
          end.map { |r| r[:work_shift_id] }
          
          # Validation 1: Mỗi nhân viên trong tuần chỉ được off tối đa:
          # - both_shifts: tối đa 2 ca (có thể 2 ca trong 1 ngày, hoặc 1 ca mỗi ngày trong 2 ngày)
          # - morning_only/afternoon_only: tối đa 1 ngày (1 ca)
          # LƯU Ý: Chỉ tính là "off" khi user đã có ít nhất 1 đăng ký trong tuần
          # Nếu user chưa đăng ký gì cả → không tính là "off"
          if all_regs.any?
            if user.work_schedule_type == 'both_shifts'
              # Đếm số ca bắt buộc bị thiếu (off) cho both_shifts
              off_shift_count = 0
              week_dates.each do |date|
                date_regs = all_regs.select { |r| r[:work_date] == date }
                
                has_morning = date_regs.any? { |r| r[:work_shift_id] == morning_shift_id }
                has_afternoon = date_regs.any? { |r| r[:work_shift_id] == afternoon_shift_id }
                
                # Đếm số ca bị thiếu trong ngày này
                off_shift_count += 1 unless has_morning
                off_shift_count += 1 unless has_afternoon
              end
              
              # both_shifts: tối đa X ca off (configurable)
              max_off_shifts = AppSetting.current.max_user_off_shifts_per_week
              if off_shift_count > max_off_shifts
                errors << {
                  type: 'user_off_limit',
                  message: "Bạn chỉ được off tối đa #{max_off_shifts} ca/tuần. Hiện tại bạn đang off #{off_shift_count} ca.",
                  week_start: week_start.to_s,
                  off_count: off_shift_count
                }
              end
            else
              # morning_only/afternoon_only: Đếm số ngày mà user thiếu ca bắt buộc (off)
              off_dates = []
              week_dates.each do |date|
                date_regs = all_regs.select { |r| r[:work_date] == date }
                
                case user.work_schedule_type
                when 'morning_only'
                  has_morning = date_regs.any? { |r| r[:work_shift_id] == morning_shift_id }
                  off_dates << date unless has_morning
                when 'afternoon_only'
                  has_afternoon = date_regs.any? { |r| r[:work_shift_id] == afternoon_shift_id }
                  off_dates << date unless has_afternoon
                end
              end
              
              # morning_only/afternoon_only: tối đa X ngày off (configurable)
              max_off_days = AppSetting.current.max_user_off_days_per_week
              if off_dates.size > max_off_days
                errors << {
                  type: 'user_off_limit',
                  message: "Bạn chỉ được off tối đa #{max_off_days} ngày/tuần. Hiện tại bạn đang off #{off_dates.size} ngày.",
                  week_start: week_start.to_s,
                  off_dates: off_dates.map(&:to_s),
                  off_count: off_dates.size
                }
              end
            end
          end
          
          # Validation 2: Mỗi ca chỉ được phép off tối đa X người / ca / ngày / vị trí (chỉ validate ca bắt buộc)
          # QUAN TRỌNG: Chỉ tính là "off" khi user đã có ít nhất 1 đăng ký trong tuần VÀ không đăng ký ca bắt buộc của ngày đó
          # Ví dụ: Nhân viên A đã đăng ký thứ 2,3,4,5,7,CN nhưng không đăng ký thứ 6 => A đã "off" thứ 6
          # => Các nhân viên khác (cùng vị trí) không được off thứ 6 nữa (nếu đã đủ số người off tối đa)
          
          week_dates.each do |date|
            date_regs = all_regs.select { |r| r[:work_date] == date }
            
            # Check morning shift - chỉ validate nếu đây là ca bắt buộc của user
            if morning_shift_id && (user.work_schedule_type == 'both_shifts' || user.work_schedule_type == 'morning_only')
              morning_reg = date_regs.find { |r| r[:work_shift_id] == morning_shift_id }
              if morning_reg.nil?
                # User muốn off ca sáng (ca bắt buộc) - check xem đã có ai CÙNG VỊ TRÍ off chưa
                # Logic: Mỗi ca/ngày/vị trí chỉ được off tối đa X người
                # - Lấy position_id của user (nếu có)
                user_position_id = user.position_id
                
                # - Tìm tất cả người CÙNG VỊ TRÍ, BẮT BUỘC làm ca sáng (không tính user hiện tại)
                #   Cùng vị trí = cùng position_id (nếu có) HOẶC cùng không có position
                same_position_users_query = User
                  .where(work_schedule_type: [:both_shifts, :morning_only])
                  .where.not(id: user.id)
                
                # Nếu user có position, chỉ check những người cùng position
                # Nếu user không có position, chỉ check những người không có position
                if user_position_id.present?
                  same_position_users_query = same_position_users_query.where(position_id: user_position_id)
                else
                  same_position_users_query = same_position_users_query.where(position_id: nil)
                end
                
                same_position_users = same_position_users_query.pluck(:id)
                total_same_position = same_position_users.size
                
                # - Đếm số người CÙNG VỊ TRÍ, BẮT BUỘC làm ca sáng ĐÃ ĐĂNG KÝ ca sáng (không tính user hiện tại)
                # CHỈ ĐẾM APPROVED (pending sẽ bị xóa khi submit)
                registered_morning_user_ids = ShiftRegistration
                  .where(work_date: date, work_shift_id: morning_shift_id, status: :approved)
                  .where.not(user_id: user.id)
                  .where(user_id: same_position_users)  # Chỉ check những người cùng position
                  .pluck(:user_id)
                
                # Cộng thêm các ca mới đang submit (từ week_regs) cho cùng ngày/ca
                required_registered_count = registered_morning_user_ids.size
                
                # QUAN TRỌNG: Chỉ tính là "off" khi user đã có ít nhất 1 đăng ký trong tuần
                # Tìm những người CÙNG VỊ TRÍ đã có ít nhất 1 đăng ký trong tuần này (CHỈ APPROVED, pending sẽ bị xóa)
                users_with_registrations = ShiftRegistration
                  .where(week_start: week_start, status: :approved)
                  .where(user_id: same_position_users)
                  .where.not(user_id: user.id)
                  .distinct
                  .pluck(:user_id)
                
                # Chỉ tính những người đã có đăng ký trong tuần là "off" nếu họ không đăng ký ca sáng ngày này
                # Nếu user đã có đăng ký trong tuần VÀ không đăng ký ca sáng ngày này => tính là "off"
                off_users = users_with_registrations.select do |other_user_id|
                  # User này đã có đăng ký trong tuần nhưng KHÔNG đăng ký ca sáng ngày này
                  !registered_morning_user_ids.include?(other_user_id)
                end
                
                off_morning_count = off_users.size
                
                # Nếu đã có >= max_shift_off_count người off rồi, thì user này không được off nữa
                max_shift_off = AppSetting.current.max_shift_off_count_per_day
                if off_morning_count >= max_shift_off
                  position_name = user.position&.name || 'vị trí này'
                  errors << {
                    type: 'shift_off_limit',
                    message: "Ca sáng ngày #{date.strftime('%d/%m/%Y')} đã đủ số người off (#{max_shift_off} người/ca/vị trí). Vui lòng chọn ca khác.",
                    date: date.to_s,
                    shift_id: morning_shift_id,
                    shift_name: 'Ca sáng',
                    off_count: off_morning_count + 1,
                    position_id: user_position_id
                  }
                end
              end
            end
            
            # Check afternoon shift - chỉ validate nếu đây là ca bắt buộc của user
            if afternoon_shift_id && (user.work_schedule_type == 'both_shifts' || user.work_schedule_type == 'afternoon_only')
              afternoon_reg = date_regs.find { |r| r[:work_shift_id] == afternoon_shift_id }
              if afternoon_reg.nil?
                # User muốn off ca chiều (ca bắt buộc) - check xem đã có ai CÙNG VỊ TRÍ off chưa
                # Logic: Mỗi ca/ngày/vị trí chỉ được off tối đa X người
                # - Lấy position_id của user (nếu có)
                user_position_id = user.position_id
                
                # - Tìm tất cả người CÙNG VỊ TRÍ, BẮT BUỘC làm ca chiều (không tính user hiện tại)
                #   Cùng vị trí = cùng position_id (nếu có) HOẶC cùng không có position
                same_position_users_query = User
                  .where(work_schedule_type: [:both_shifts, :afternoon_only])
                  .where.not(id: user.id)
                
                # Nếu user có position, chỉ check những người cùng position
                # Nếu user không có position, chỉ check những người không có position
                if user_position_id.present?
                  same_position_users_query = same_position_users_query.where(position_id: user_position_id)
                else
                  same_position_users_query = same_position_users_query.where(position_id: nil)
                end
                
                same_position_users = same_position_users_query.pluck(:id)
                
                # - Đếm số người CÙNG VỊ TRÍ, BẮT BUỘC làm ca chiều ĐÃ ĐĂNG KÝ ca chiều (không tính user hiện tại)
                # CHỈ ĐẾM APPROVED (pending sẽ bị xóa khi submit)
                registered_afternoon_user_ids = ShiftRegistration
                  .where(work_date: date, work_shift_id: afternoon_shift_id, status: :approved)
                  .where.not(user_id: user.id)
                  .where(user_id: same_position_users)  # Chỉ check những người cùng position
                  .pluck(:user_id)
                
                required_registered_count = registered_afternoon_user_ids.size
                
                # QUAN TRỌNG: Chỉ tính là "off" khi user đã có ít nhất 1 đăng ký trong tuần
                # Tìm những người CÙNG VỊ TRÍ đã có ít nhất 1 đăng ký trong tuần này (CHỈ APPROVED, pending sẽ bị xóa)
                users_with_registrations = ShiftRegistration
                  .where(week_start: week_start, status: :approved)
                  .where(user_id: same_position_users)
                  .where.not(user_id: user.id)
                  .distinct
                  .pluck(:user_id)
                
                # Chỉ tính những người đã có đăng ký trong tuần là "off" nếu họ không đăng ký ca chiều ngày này
                off_users = users_with_registrations.select do |other_user_id|
                  # User này đã có đăng ký trong tuần nhưng KHÔNG đăng ký ca chiều ngày này
                  !registered_afternoon_user_ids.include?(other_user_id)
                end
                
                off_afternoon_count = off_users.size
                
                # Nếu đã có >= max_shift_off_count người off rồi, thì user này không được off nữa
                max_shift_off = AppSetting.current.max_shift_off_count_per_day
                if off_afternoon_count >= max_shift_off
                  position_name = user.position&.name || 'vị trí này'
                  errors << {
                    type: 'shift_off_limit',
                    message: "Ca chiều ngày #{date.strftime('%d/%m/%Y')} đã đủ số người off (#{max_shift_off} người/ca/vị trí). Vui lòng chọn ca khác.",
                    date: date.to_s,
                    shift_id: afternoon_shift_id,
                    shift_name: 'Ca chiều',
                    off_count: off_afternoon_count + 1,
                    position_id: user_position_id
                  }
                end
              end
            end
          end
        end
        
        errors
      end
    end
  end
end

