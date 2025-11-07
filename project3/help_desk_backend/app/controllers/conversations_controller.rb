class ConversationsController < ApplicationController
  before_action :authorize_request

  # GET /conversations
  def index
    conversations = Conversation
                      .includes(:initiator, :assigned_expert, :messages)
                      .where("initiator_id = ? OR assigned_expert_id = ?", @current_user.id, @current_user.id)
                      .order(updated_at: :desc)

    render json: conversations.map { |c| serialize_conversation(c) }, status: :ok
  end



# GET /conversations/:id
  def show
    conversation = Conversation
                     .includes(:initiator, :assigned_expert, :messages)
                     .find_by(id: params[:id])

    if conversation.nil?
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end

    unless [conversation.initiator_id, conversation.assigned_expert_id].include?(@current_user.id)
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end

    render json: serialize_conversation(conversation), status: :ok
  end


  # POST /conversations
  def create
    conversation = Conversation.new(
      title: params[:title],
      status: "waiting",
      initiator: @current_user
    )

    if conversation.save
      render json: serialize_conversation(conversation), status: :created
    else
      render json: { errors: conversation.errors.full_messages }, status: :unprocessable_entity
    end
  end


  
  def updates
    authorize_request

    user_id = params[:userId]
    since_param = params[:since]

    unless user_id.present? && user_id.to_i == @current_user.id
      return render json: { error: "Invalid or missing userId" }, status: :unauthorized
    end

    since_time = since_param.present? ? (Time.iso8601(since_param) rescue nil) : nil

    conversations = Conversation
                      .where("initiator_id = :id OR assigned_expert_id = :id", id: @current_user.id)
                      .includes(:initiator, :assigned_expert, :messages)
                      .order(updated_at: :desc)

    if since_time
      conversations = conversations.where("conversations.updated_at > ? OR messages.updated_at > ?", since_time, since_time).references(:messages)
    end

    render json: conversations.map { |c| serialize_conversation(c) }, status: :ok
  end



  private

  def authorize_request
    header = request.headers["Authorization"]
    token = header.split(" ").last if header
    decoded = JWT.decode(token, Rails.application.secret_key_base)[0] rescue nil
    # decoded = JwtService.decode(token)
    @current_user = User.find(decoded["user_id"]) if decoded
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def serialize_conversation(c)
    {
      id: c.id.to_s,
      title: c.title,
      status: c.status,
      questionerId: c.initiator_id.to_s,
      questionerUsername: c.initiator.username,
      assignedExpertId: c.assigned_expert_id,
      assignedExpertUsername: c.assigned_expert&.username,
      createdAt: c.created_at.iso8601,
      updatedAt: c.updated_at.iso8601,
      lastMessageAt: c.messages.last&.created_at&.iso8601,
    #   unreadCount: c.messages.where(is_read: false, sender_id: @current_user.id).count
      unreadCount: c.messages.where(is_read: false).where.not(sender_id: @current_user.id).count

    }
  end
end
