class Admin::UsersController < AdminController
  respond_to :html

  def dashboard
  end

  def login
    @user = User.new
  end

  def authenticate
    @current_user = User.authorize(params[:user][:login], params[:user][:password])
    session[:user_id] = @current_user.id
    
    if current_user
      flash[:notice] = "Welcome #{current_user.name}!"
      redirect_to admin_root_path
    else
      flash[:error] = 'We could not log you in. Please try again.'
      redirect_to login_admin_users_path
    end
  end

  def logout
    session[:user_id] = nil
    redirect_to admin_root_path
  end

  def search
    @users = User.full_search(params[:user]).paginate(pagination_hash)
  end

  def new
    @user = User.create_from_search_params(params[:user])
  end

  def update
    @user = User.find(params[:id])
    if @user.update_attributes(params[:user])
      flash[:notice] = "#{@user.name} has been saved."
      respond_with [:admin, @user]
    else
      flash[:error] = 'There were an error saving your user. Please try again.'
      render template: 'admin/users/new'
    end
  end

  def show
    @user = User.find(params[:id])
  end

end