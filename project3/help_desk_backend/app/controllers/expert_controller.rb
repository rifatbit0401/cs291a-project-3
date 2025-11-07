class ExpertController < ApplicationController
  before_action :authorize_request

  # GET /expert/queue
  def queue
    expert_profile = @current_user.expert_profile
    unless expert_profile
      return render json: { error: "Only experts can access this endpoint" }, status: :forbidden
    end

    waiting_conversations = Conversation
                              .where(status: "waiting", assigned_expert_id: nil)
                              .order(created_at: :desc)

    assigned_conversations = Conversation
                                .where(assigned_expert_id: @current_user.id)
                                .order(updated_at: :desc)

    render json: {
      waitingConversations: waiting_conversations.map { |c| serialize_conversation(c) },
      assignedConversations: assigned_conversations.map { |c| serialize_conversation(c) }
    }, status: :ok
  end


  def claim
    expert_profile = @current_user.expert_profile
    unless expert_profile
      return render json: { error: "Only experts can claim conversations" }, status: :forbidden
    end

    conversation = Conversation.find_by(id: params[:conversation_id])
    return render json: { error: "Conversation not found" }, status: :not_found unless conversation

    if conversation.assigned_expert_id.present?
      return render json: { error: "Conversation is already assigned to an expert" }, status: :unprocessable_entity
    end

    conversation.assigned_expert_id = @current_user.id
    conversation.status = "active"

    if conversation.save
      render json: { success: true }, status: :ok
    else
      render json: { error: "Failed to assign expert" }, status: :unprocessable_entity
    end
  end


def unclaim
  expert_profile = @current_user.expert_profile
  unless expert_profile
    return render json: { error: "Only experts can unclaim conversations" }, status: :forbidden
  end

  conversation = Conversation.find_by(id: params[:conversation_id])
  return render json: { error: "Conversation not found" }, status: :not_found unless conversation

  unless conversation.assigned_expert_id == @current_user.id
    return render json: { error: "You are not assigned to this conversation" }, status: :forbidden
  end

  conversation.assigned_expert_id = nil
  conversation.status = "waiting"

  if conversation.save
    render json: { success: true }, status: :ok
  else
    render json: { error: "Failed to unclaim conversation" }, status: :unprocessable_entity
  end
end


def profile
  expert_profile = @current_user.expert_profile

  unless expert_profile
    return render json: { error: "Expert profile not found" }, status: :not_found
  end

  render json: {
    id: expert_profile.id,
    userId: expert_profile.user_id,
    bio: expert_profile.bio,
    knowledgeBaseLinks: expert_profile.knowledge_base_links,
    createdAt: expert_profile.created_at.iso8601,
    updatedAt: expert_profile.updated_at.iso8601
  }, status: :ok
end



def update_profile
  expert_profile = @current_user.expert_profile

  unless expert_profile
    return render json: { error: "Expert profile not found" }, status: :not_found
  end

  bio = params[:bio]
  knowledge_links = params[:knowledgeBaseLinks] || params[:knowledge_base_links]

  if expert_profile.update(bio: bio, knowledge_base_links: knowledge_links)
    render json: {
      id: expert_profile.id,
      userId: expert_profile.user_id,
      bio: expert_profile.bio,
      knowledgeBaseLinks: expert_profile.knowledge_base_links,
      createdAt: expert_profile.created_at.iso8601,
      updatedAt: expert_profile.updated_at.iso8601
    }, status: :ok
  else
    render json: { error: expert_profile.errors.full_messages }, status: :unprocessable_entity
  end
end




def assignment_history
  expert_profile = @current_user.expert_profile

  unless expert_profile
    return render json: { error: "Only experts can view assignment history" }, status: :forbidden
  end
  assignments = ExpertAssignment
                  .includes(:conversation)
                  .where(expert_id: @current_user.id)
                  .order(created_at: :desc)

  render json: assignments.map { |a| serialize_assignment(a) }, status: :ok
end


def queue_updates
  authorize_request

  expert_id = params[:expertId]
  since_param = params[:since]

  unless expert_id.present? && expert_id.to_i == @current_user.id
    return render json: { error: "Invalid or missing expertId" }, status: :unauthorized
  end

  unless @current_user.expert_profile
    return render json: { error: "Only experts can access this endpoint" }, status: :forbidden
  end

  since_time = since_param.present? ? (Time.iso8601(since_param) rescue nil) : nil

  waiting = Conversation
              .where(status: "waiting")
              .includes(:initiator, :messages)
              .order(updated_at: :desc)
  waiting = waiting.where("conversations.updated_at > ?", since_time) if since_time

  assigned = Conversation
               .where(assigned_expert_id: @current_user.id)
               .includes(:initiator, :assigned_expert, :messages)
               .order(updated_at: :desc)
  assigned = assigned.where("conversations.updated_at > ?", since_time) if since_time

  render json: [{
    waitingConversations: waiting.map { |c| serialize_conversation(c) },
    assignedConversations: assigned.map { |c| serialize_conversation(c) }
  }], status: :ok
end


private

def serialize_assignment(a)
  {
    id: a.id,
    conversationId: a.conversation_id,
    expertId: a.expert_id,
    status: a.conversation.status,
    assignedAt: a.created_at.iso8601,
    resolvedAt: a.conversation.updated_at&.iso8601,
    rating: a.rating
  }
end




  private
   def authorize_request
    header = request.headers["Authorization"]
    token = header.split(" ").last if header
    decoded = JWT.decode(token, Rails.application.secret_key_base)[0] rescue nil
    @current_user = User.find(decoded["user_id"]) if decoded
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def serialize_conversation(c)
    {
      id: c.id,
      title: c.title,
      status: c.status,
      questionerId: c.initiator_id,
      questionerUsername: c.initiator.username,
      assignedExpertId: c.assigned_expert_id,
      assignedExpertUsername: c.assigned_expert&.username,
      createdAt: c.created_at.iso8601,
      updatedAt: c.updated_at.iso8601,
      lastMessageAt: c.messages.order(created_at: :desc).first&.created_at&.iso8601,
      unreadCount: c.messages.where(is_read: false, sender_id: c.initiator_id).count
    }
  end
end
