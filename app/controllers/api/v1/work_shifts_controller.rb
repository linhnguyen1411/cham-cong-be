# app/controllers/api/v1/work_shifts_controller.rb
module Api
  module V1
    class WorkShiftsController < ApplicationController
      before_action :set_work_shift, only: [:show, :update, :destroy]
      
      # GET /api/v1/work_shifts
      def index
        @work_shifts = if params[:department_id].present?
          WorkShift.where(department_id: params[:department_id])
        else
          WorkShift.all
        end
        
        render json: @work_shifts.map { |s|
          s.as_json.merge(department_name: s.department&.name)
        }
      end
      
      def show
        render json: @work_shift.as_json.merge(department_name: @work_shift.department&.name)
      end
      
      # POST /api/v1/work_shifts
      def create
        @work_shift = WorkShift.new(work_shift_params)
        
        if @work_shift.save
          render json: @work_shift.as_json.merge(department_name: @work_shift.department&.name), status: :created
        else
          render json: { errors: @work_shift.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PATCH/PUT /api/v1/work_shifts/:id
      def update
        if @work_shift.update(work_shift_params)
          render json: @work_shift.as_json.merge(department_name: @work_shift.department&.name)
        else
          render json: { errors: @work_shift.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/work_shifts/:id
      def destroy
        @work_shift.destroy
        head :no_content
      end
      
      private
      
      def set_work_shift
        @work_shift = WorkShift.find(params[:id])
      end
      
      def work_shift_params
        params.require(:work_shift).permit(:name, :start_time, :end_time, :late_threshold, :department_id)
      end
    end
  end
end