module Alchemy
  module Admin
    class UsersController < ResourcesController

      before_action :set_roles_and_genders, except: [:index, :destroy]
      after_action :deliver_welcome_mail, only: [:create, :update]

      load_and_authorize_resource class: Alchemy::User,
        only: [:edit, :update, :destroy]

      authorize_resource class: Alchemy::User,
        only: [:index, :new, :signup, :create]

      helper_method :while_signup?, :can_update_role?

      def index
        @query = User.ransack(params[:q])
        @query.sorts = 'login asc' if @query.sorts.empty?
        @users = @query.result
          .page(params[:page] || 1)
          .per(per_page_value_for_screen_size)
      end

      def new
        @user = User.new(send_credentials: true)
      end

      def signup
        if while_signup?
          new
        else
          flash[:warning] = _t(:cannot_signup_more_then_once)
          redirect_to admin_dashboard_path
        end
      end

      def create
        @user = User.new(user_params)

        if while_signup?
          signup_admin_or_redirect(@user)
        else
          create_user_or_redirect(@user)
        end
      end

      def update
        # User is fetched via before filter
        if params[:user][:password].present?
          @user.update(user_params)
        else
          @user.update_without_password(user_params)
        end

        render_errors_or_redirect @user,
          admin_users_path,
          _t("User updated", :name => @user.name)
      end

      def destroy
        # User is fetched via before filter
        name = @user.name
        if @user.destroy
          flash[:notice] = _t("User deleted", name: name)
        end
        do_redirect_to admin_users_path
      end

      private

      def set_roles_and_genders
        if can_update_role?
          @user_roles = User::ROLES.map do |role|
            [User.human_rolename(role), role]
          end
        end
        @user_genders = User.genders_for_select
      end

      def user_params
        params.require(:user).permit(*secure_attributes)
      end

      def secure_attributes
        if can_update_role?
          User::PERMITTED_ATTRIBUTES + [{alchemy_roles: []}]
        else
          User::PERMITTED_ATTRIBUTES
        end
      end

      def while_signup?
        User.count == 0
      end

      def signup_admin_or_redirect(user)
        user.alchemy_roles = %w(admin)
        if user.save
          flash[:notice] = _t('Successfully signup admin user')
          sign_in :user, user
          redirect_to admin_pages_path
        else
          render :signup
        end
      end

      def create_user_or_redirect(user)
        user.save
        render_errors_or_redirect user,
          admin_users_path,
          _t("User created", name: user.name)
      end

      def can_update_role?
        can? :update_role, Alchemy::User
      end

      def deliver_welcome_mail
        if @user.valid? && @user.send_credentials == '1'
          @user.deliver_welcome_mail
        end
      end
    end
  end
end
