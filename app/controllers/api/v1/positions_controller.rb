# app/controllers/api/v1/positions_controller.rb
module Api
  module V1
    class PositionsController < ApplicationController
      before_action :set_position, only: [:show, :update, :destroy]
      
      # GET /api/v1/positions
      def index
        @positions = Position.all
        
        # Filter by branch
        @positions = @positions.by_branch(params[:branch_id]) if params[:branch_id].present?
        
        # Filter by department
        @positions = @positions.by_department(params[:department_id]) if params[:department_id].present?
        
        render json: @positions.includes(:branch, :department, :users)
      end
      
      # GET /api/v1/positions/:id
      def show
        render json: @position
      end
      
      # POST /api/v1/positions
      def create
        @position = Position.new(position_params)
        
        if @position.save
          render json: @position, status: :created
        else
          render json: { errors: @position.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/positions/:id
      def update
        if @position.update(position_params)
          render json: @position
        else
          render json: { errors: @position.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/positions/:id
      def destroy
        if @position.users.exists?
          render json: { error: 'Không thể xóa vị trí đang có nhân viên' }, status: :unprocessable_entity
        else
          @position.destroy
          head :no_content
        end
      end
      
      private
      
      def set_position
        @position = Position.find(params[:id])
      end
      
      def position_params
        params.require(:position).permit(:name, :description, :branch_id, :department_id, :level)
      end
    end
  end
end

