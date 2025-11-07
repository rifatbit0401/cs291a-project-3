class MessagesController < ApplicationController
  before_action :authorize_request
  before_action :set_conversation, only: [:index] 

  # GET /conversations/:conversation_id/messages
  def index
    messages = @conversation.messages.includes(:sender).order(:created_at)
    render json: messages.map { |m| serialize_message(m) }, status: :ok
  end


  # POST /messages
  def create
    conversation = Conversation.find_by(id: params[:conversationId] || params[:conversation_id])
    return render json: { error: "Conversation not found" }, status: :not_found unless conversation

    unless [conversation.initiator_id, conversation.assigned_expert_id].include?(@current_user.id)
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end


    sender_role =
    if @current_user.id == conversation.initiator_id
      "initiator"
    elsif @current_user.id == conversation.assigned_expert_id
      "expert"
    end

    message = conversation.messages.new(
      sender: @current_user,
      content: params[:content],
      is_read: false,
      sender_role: sender_role
    )

    if message.save
      render json: serialize_message(message), status: :created
    else
      render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
    end
  end



# PUT /messages/:id/read
def mark_as_read
  message = Message.find_by(id: params[:id])
  return render json: { error: "Message not found" }, status: :not_found unless message

  conversation = message.conversation
  unless [conversation.initiator_id, conversation.assigned_expert_id].include?(@current_user.id)
    return render json: { error: "Unauthorized" }, status: :unauthorized
  end
  if message.sender_id == @current_user.id
    return render json: { error: "Cannot mark your own messages as read" }, status: :forbidden
  end
  if message.update(is_read: true)
    render json: { success: true }, status: :ok
  else
    render json: { error: "Failed to update message" }, status: :unprocessable_entity
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
  messages = Message
               .joins(:conversation)
               .where("conversations.initiator_id = :id OR conversations.assigned_expert_id = :id", id: @current_user.id)
               .includes(:sender, :conversation)
               .order(created_at: :desc)

  messages = messages.where("messages.updated_at > ?", since_time) if since_time
  render json: messages.map { |m| serialize_message(m) }, status: :ok
end



  private

  def authorize_request
    header = request.headers["Authorization"]
    token = header.split(" ").last if header
    decoded = JWT.decode(token, Rails.application.secret_key_base)[0] rescue nil
    @current_user = User.find(decoded["user_id"]) if decoded
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def set_conversation
    conv_id = params[:conversation_id] || params[:conversationId]
    @conversation = Conversation.find_by(id: conv_id)
    render json: { error: "Conversation not found" }, status: :not_found unless @conversation
  end

  def serialize_message(m)
    {
      id: m.id,
      conversationId: m.conversation_id,
      senderId: m.sender_id,
      senderUsername: m.sender.username,
      senderRole: sender_role(m),
      content: m.content,
      timestamp: m.created_at.iso8601,
      isRead: m.is_read
    }
  end

  def sender_role(m)
    # if m.sender_id == @conversation.initiator_id
    #   "initiator"
    # elsif m.sender_id == @conversation.assigned_expert_id
    #   "expert"
    # else
    #   "unknown"
    # end
    conversation = m.conversation
    if m.sender_id == conversation.initiator_id
      "initiator"
    elsif m.sender_id == conversation.assigned_expert_id
      "expert"
    else
      "unknown"
    end
  end
end
