package net.boyblack.robotlegs.mvcs
{
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.utils.Dictionary;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;

	import net.boyblack.robotlegs.core.IMediator;
	import net.boyblack.robotlegs.core.IMediatorFactory;
	import net.boyblack.robotlegs.utils.DelayedFunctionQueue;
	import net.expantra.smartypants.Injector;
	import net.expantra.smartypants.utils.Reflection;

	public class MediatorFactory implements IMediatorFactory
	{
		// Error Constants ////////////////////////////////////////////////////
		private static const E_CONF_MED_IMPL:String = 'RobotLegs MediatorFactory Config Error: Mediator Class does not implement IMediator';

		// Protected Properties ///////////////////////////////////////////////
		protected var injector:Injector;
		protected var mediatorByView:Dictionary;
		protected var mediatorClassByViewClassName:Dictionary;
		protected var contextView:DisplayObject;
		protected var useCapture:Boolean;

		// API ////////////////////////////////////////////////////////////////
		public function MediatorFactory( injector:Injector, contextView:DisplayObject, useCapture:Boolean = true )
		{
			this.injector = injector;
			this.contextView = contextView;
			this.mediatorByView = new Dictionary( true );
			this.mediatorClassByViewClassName = new Dictionary( false );
			this.useCapture = useCapture;
			initializeListeners();
		}

		public function mapMediator( viewClass:Class, mediatorClass:Class ):void
		{
			if ( Reflection.classExtendsOrImplements( mediatorClass, IMediator ) == false )
			{
				throw new Error( E_CONF_MED_IMPL + ' - ' + mediatorClass );
			}
			var viewClassName:String = getQualifiedClassName( viewClass );
			mediatorClassByViewClassName[ viewClassName ] = mediatorClass;
		}

		public function createMediator( viewComponent:Object ):IMediator
		{
			var mediator:IMediator = mediatorByView[ viewComponent ];
			if ( mediator == null )
			{
				var viewClassName:String = getQualifiedClassName( viewComponent );
				var viewClass:Class = getDefinitionByName( viewClassName ) as Class;
				var mediatorClass:Class = mediatorClassByViewClassName[ viewClassName ];
				if ( mediatorClass )
				{
					mediator = new mediatorClass();
					trace( '[ROBOTLEGS] Mediator (' + mediator + ') constructed for View Component (' + viewComponent + ')' );
					injector.newRule().whenAskedFor( viewClass ).useValue( viewComponent );
					injector.injectInto( mediator );
					injector.newRule().whenAskedFor( viewClass ).defaultBehaviour();
					injector.newRule().whenAskedFor( mediatorClass ).useValue( mediator );
					registerMediator( mediator, viewComponent );
				}
			}
			return mediator;
		}

		public function registerMediator( mediator:IMediator, viewComponent:Object ):void
		{
			mediatorByView[ viewComponent ] = mediator;
			mediator.setViewComponent( viewComponent );
			mediator.onRegister();
			trace( '[ROBOTLEGS] Mediator (' + mediator + ') Registered' );
		}

		public function removeMediator( mediator:IMediator ):IMediator
		{
			if ( mediator )
			{
				var viewComponent:Object = mediator.getViewComponent();
				var viewClassName:String = getQualifiedClassName( viewComponent );
				var viewClass:Class = getDefinitionByName( viewClassName ) as Class;
				mediatorByView[ viewComponent ] = null;
				mediator.onRemove();
				mediator.setViewComponent( null );
				injector.newRule().whenAskedFor( viewClass ).defaultBehaviour();
				injector.injectInto( mediator );
				trace( '[ROBOTLEGS] Mediator (' + mediator + ') Removed' );
			}
			return mediator;
		}

		public function removeMediatorByView( viewComponent:Object ):IMediator
		{
			return removeMediator( retrieveMediator( viewComponent ) );
		}

		public function retrieveMediator( viewComponent:Object ):IMediator
		{
			return mediatorByView[ viewComponent ];
		}

		public function hasMediator( viewComponent:Object ):Boolean
		{
			return mediatorByView[ viewComponent ] != null;
		}

		public function destroy():void
		{
			removeListeners();
			injector = null;
			mediatorByView = null;
			mediatorClassByViewClassName = null;
			contextView = null;
		}

		// Protected Methods //////////////////////////////////////////////////
		protected function initializeListeners():void
		{
			contextView.addEventListener( Event.ADDED_TO_STAGE, onAdded, useCapture, 0, true );
			contextView.addEventListener( Event.REMOVED_FROM_STAGE, onRemoved, useCapture, 0, true );
		}

		protected function removeListeners():void
		{
			contextView.removeEventListener( Event.ADDED_TO_STAGE, onAdded, useCapture );
			contextView.removeEventListener( Event.REMOVED_FROM_STAGE, onRemoved, useCapture );
		}

		protected function onAdded( e:Event ):void
		{
			if ( mediatorByView[ e.target ] == null )
			{
				createMediator( e.target );
			}
		}

		protected function onRemoved( e:Event ):void
		{
			if ( mediatorByView[ e.target ] != null )
			{
				trace( '[ROBOTLEGS] MediatorFactory might have mistakenly lost an ' + e.target + ', double checking...' );
				DelayedFunctionQueue.add( possiblyRemoveMediator, e.target );
			}
		}

		// Private Methods ////////////////////////////////////////////////////
		private function possiblyRemoveMediator( viewComponent:DisplayObject ):void
		{
			if ( viewComponent.stage == null )
			{
				removeMediatorByView( viewComponent );
			}
			else
			{
				trace( '[ROBOTLEGS] False alarm for ' + viewComponent );
			}
		}

	}
}