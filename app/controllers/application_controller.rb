class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

private

  def current_user
    return nil unless session[:user_id]
    begin
      @current_user = User.find(session[:user_id])
    rescue; end
  end

  def force_login
    unless is_logged_in?
      session[:previous_page] = request.referer
      redirect_to login_users_path
    end
  end
  
  def is_logged_in?
    begin
      @current_user = User.find(session[:user_id]) if session[:user_id]
    rescue
      return false
    end
  end 
  
  def force_add_email
    if !current_user
      flash[:update] = "You must be logged in as a registered user in order to checkout"
      
      session[:previous_page] = request.referer
      redirect_to register_users_path
      
    elsif current_user.emails.empty?
      flash[:update] = "We do not have an email address for you. Please add it."
      session[:previous_page] = request.referer
      redirect_to edit_user_path(current_user.id)
      
    end
  end
  

  def pagination_hash
    {
      :page => ( params[:page] or 1 ),
      :per_page => ( params[:per_page] or 9 ),
      :order => "updated_at DESC"
    }
  end
  

  require 'will_paginate/collection'
  Array.class_eval do
    def paginate(options = {})
      raise ArgumentError, "parameter hash expected (got #{options.inspect})" unless Hash === options

      WillPaginate::Collection.create(
          options[:page] || 1,
          options[:per_page] || 30,
          options[:total_entries] || self.length
      ) { |pager|
        pager.replace self[pager.offset, pager.per_page].to_a
      }
    end
  end
end
