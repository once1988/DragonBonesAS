﻿package dragonBones.factories
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.utils.ByteArray;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import dragonBones.Armature;
	import dragonBones.Bone;
	import dragonBones.Slot;
	import dragonBones.core.BaseObject;
	import dragonBones.core.DragonBones;
	import dragonBones.core.dragonBones_internal;
	import dragonBones.objects.ArmatureData;
	import dragonBones.objects.BoneData;
	import dragonBones.objects.DisplayData;
	import dragonBones.objects.DragonBonesData;
	import dragonBones.objects.SkinData;
	import dragonBones.objects.SlotData;
	import dragonBones.objects.SlotDisplayDataSet;
	import dragonBones.parsers.ObjectDataParser;
	import dragonBones.textures.TextureAtlasData;
	import dragonBones.textures.TextureData;
	
	use namespace dragonBones_internal;
	
	/** 
	 * Dispatched after a sucessful call to parseData().
	 */
	[Event(name="complete", type="flash.events.Event")]
	
	/** 
	 * @private 
	 */
	public class BaseFactory extends EventDispatcher
	{
		/**
		 * @language zh_CN
		 * 是否自动索引，如果开启自动索引，创建一个骨架时可以从多个 DragonBonesData 中寻找资源，通常用于共享导出时使用。 [<code>true</code>: 开启, <code>false</code>: 不开启] (默认: <code>false</code>)
		 * @see dragonBones.objects.DragonBonesData
		 * @version DragonBones 4.5
		 */
		public var autoSearch:Boolean = false;
		
		/** 
		 * @private 
		 */
		protected const _dragonBonesDataMap:Object = {};
		
		/** 
		 * @private 
		 */
		protected const _textureAtlasDataMap:Object = {};
		
		/** 
		 * @private 
		 */
		public function BaseFactory(self:BaseFactory)
		{
			super(this);
			
			if (self != this)
			{
				throw new Error(DragonBones.ABSTRACT_CLASS_ERROR);
			}
			
			autoSearch = false;
		}
		
		private var _delayID:uint = 0;
		private const _decodeDataList:Vector.<DecodedData> = new Vector.<DecodedData>;
		private function _loadTextureAtlasHandler(event:Event):void
		{
			const loaderInfo:LoaderInfo = event.target as LoaderInfo;
			const decodeData:DecodedData = loaderInfo.loader as DecodedData;
			loaderInfo.removeEventListener(Event.COMPLETE, _loadTextureAtlasHandler);
			parseTextureAtlasData(decodeData.textureAtlasData, decodeData.content, decodeData.name);
			decodeData.dispose();
			_decodeDataList.splice(_decodeDataList.indexOf(decodeData), 1);
			if (_decodeDataList.length == 0)
			{
				this.dispatchEvent(event);
			}
		}
		
		/** 
		 * @private
		 */
		protected function _getTextureData(textureAtlasName:String, textureName:String):TextureData
		{
			var i:uint = 0, l:uint = 0;
			var textureData:TextureData = null;
			var textureAtlasDataList:Vector.<TextureAtlasData> = _textureAtlasDataMap[textureAtlasName];
			
			if (textureAtlasDataList)
			{
				for (i = 0, l = textureAtlasDataList.length; i < l; ++i)
				{
					textureData = textureAtlasDataList[i].getTexture(textureName);
					if (textureData)
					{
						return textureData;
					}
				}
			}
			
			if (autoSearch)
			{
				for each (textureAtlasDataList in _textureAtlasDataMap)
				{
					for (i = 0, l = textureAtlasDataList.length; i < l; ++i)
					{
						const textureAtlasData:TextureAtlasData = textureAtlasDataList[i];
						if (textureAtlasData.autoSearch)
						{
							textureData = textureAtlasData.getTexture(textureName);
							if (textureData)
							{
								return textureData;
							}
						}
					}
				}
			}
			
			return textureData;
		}
		
		/** 
		 * @private
		 */
		protected function _fillBuildArmaturePackage(dragonBonesName:String, armatureName:String, skinName:String, dataPackage:BuildArmaturePackage):Boolean
		{
			var dragonBonesData:DragonBonesData = null;
			var armatureData:ArmatureData = null;
			if (dragonBonesName)
			{
				dragonBonesData = _dragonBonesDataMap[dragonBonesName];
				if (dragonBonesData)
				{
					armatureData = dragonBonesData.getArmature(armatureName);
				}
			}
			
			if (!armatureData && (!dragonBonesName || autoSearch))
			{
				for (var eachDragonBonesName:String in _dragonBonesDataMap)
				{
					dragonBonesData = _dragonBonesDataMap[eachDragonBonesName];
					if (!dragonBonesName || dragonBonesData.autoSearch)
					{
						armatureData = dragonBonesData.getArmature(armatureName);
						if (armatureData)
						{
							dragonBonesName = eachDragonBonesName;
							break;
						}
					}
				}
			}
			
			if (armatureData)
			{
				dataPackage.dataName = dragonBonesName;
				dataPackage.data = dragonBonesData;
				dataPackage.armature = armatureData;
				dataPackage.skin = armatureData.getSkin(skinName) || armatureData.defaultSkin;
				return true;
			}
			
			return false;
		}
		
		/** 
		 * @private
		 */
		protected function _buildBones(dataPackage:BuildArmaturePackage, armature:Armature):void
		{
			const bones:Vector.<BoneData> = dataPackage.armature.sortedBones;
			
			for (var i:uint = 0, l:uint = bones.length; i < l; ++i)
			{
				const boneData:BoneData = bones[i];
				const bone:Bone = BaseObject.borrowObject(Bone) as Bone;
				
				bone.name = boneData.name;
				bone.inheritTranslation = boneData.inheritTranslation; 
				bone.inheritRotation = boneData.inheritRotation; 
				bone.inheritScale = boneData.inheritScale; 
				bone.length = boneData.length;
				bone.origin.copy(boneData.transform);
				if (boneData.parent)
				{
					armature.addBone(bone, boneData.parent.name);
				}
				else
				{
					armature.addBone(bone);
				}
				
				if (boneData.ik)
				{
					bone.ikBendPositive = boneData.bendPositive;
					bone.ikWeight = boneData.weight;
					bone._setIK(armature.getBone(boneData.ik.name), boneData.chain, boneData.chainIndex);
				}
			}
		}
		
		/** 
		 * @private
		 */
		protected function _buildSlots(dataPackage:BuildArmaturePackage, armature:Armature):void
		{
			const currentSkin:SkinData = dataPackage.skin;
			const defaultSkin:SkinData = dataPackage.armature.defaultSkin;
			const slotDisplayDataSetMap:Object = {};
			
			var slotName:String = null;
			var slotDisplayDataSet:SlotDisplayDataSet = null;
			
			for each (slotDisplayDataSet in defaultSkin.slots)
			{
				slotDisplayDataSetMap[slotDisplayDataSet.slot.name] = slotDisplayDataSet;
			}
			
			if (currentSkin != defaultSkin)
			{
				for each (slotDisplayDataSet in currentSkin.slots)
				{
					slotDisplayDataSetMap[slotDisplayDataSet.slot.name] = slotDisplayDataSet;
				}
			}
			
			const slots:Vector.<SlotData> = dataPackage.armature.sortedSlots;
			for each (var slotData:SlotData in slots)
			{
				slotDisplayDataSet = slotDisplayDataSetMap[slotData.name];
				if (!slotDisplayDataSet)
				{
					continue;
				}
				
				const slot:Slot = _generateSlot(dataPackage, slotDisplayDataSet);
				
				slot._displayDataSet = slotDisplayDataSet;
				slot._setDisplayIndex(slotData.displayIndex);
				slot._setBlendMode(slotData.blendMode);
				slot._setColor(slotData.color);
				
				slot._replaceDisplayDataSet.fixed = false;
				slot._replaceDisplayDataSet.length = slotDisplayDataSet.displays.length;
				slot._replaceDisplayDataSet.fixed = true;
				
				armature.addSlot(slot, slotData.parent.name);
			}
		}
		
		/** 
		 * @private
		 */
		protected function _replaceSlotDisplay(dataPackage:BuildArmaturePackage, displayData:DisplayData, slot:Slot, displayIndex:int):void
		{
			if (!displayData)
			{
				return;
			}
			
			if (displayIndex < 0)
			{
				displayIndex = slot.displayIndex;
			}
			
			if (displayIndex < 0)
			{
				return;
			}
			else
			{
				if (slot._replaceDisplayDataSet.length <= displayIndex)
				{
					slot._replaceDisplayDataSet.fixed = false;
					slot._replaceDisplayDataSet.length = displayIndex + 1;
					slot._replaceDisplayDataSet.fixed = true;
				}
				
				slot._replaceDisplayDataSet[displayIndex] = displayData;
				
				const displayList:Vector.<Object> = slot.displayList;
				if (displayList.length <=  displayIndex)
				{
					displayList.fixed = false;
					displayList.length = displayIndex + 1;
				}
				
				if (displayData.meshData)
				{
					displayList[displayIndex] = slot.MeshDisplay;
				}
				else
				{
					displayList[displayIndex] = slot.rawDisplay;
				}
				
				slot.displayList = displayList;
				slot.invalidUpdate();
			}
		}
		
		/** 
		 * @private
		 */
		protected function _generateTextureAtlasData(textureAtlasData:TextureAtlasData, textureAtlas:Object):TextureAtlasData
		{
			throw new Error(DragonBones.ABSTRACT_METHOD_ERROR);
			return null;
		}
		
		/** 
		 * @private
		 */
		protected function _generateArmature(dataPackage:BuildArmaturePackage):Armature
		{
			throw new Error(DragonBones.ABSTRACT_METHOD_ERROR);
			return null;
		}
		
		/** 
		 * @private
		 */
		protected function _generateSlot(dataPackage:BuildArmaturePackage, slotDisplayDataSet:SlotDisplayDataSet):Slot
		{
			throw new Error(DragonBones.ABSTRACT_METHOD_ERROR);
			return null;
		}
		
		/**
		 * @language zh_CN
		 * 解析龙骨数据，并将解析后的数据添加到工厂。
		 * @param rawData 需要解析的原始数据。 (JSON 或 合并后的 PNG 和 SWF 文件)
		 * @param dragonBonesName 为解析后的数据提供一个名称，以便可以通过这个名称来访问数据，如果不提供，则使用数据中的名称。 (默认: <code>null</code>)
		 * @return DragonBonesData
		 * @see #getDragonBonesData()
		 * @see #addDragonBonesData()
		 * @see #removeDragonBonesData()
		 * @see dragonBones.objects.DragonBonesData
		 * @version DragonBones 4.5
		 */
		public function parseDragonBonesData(rawData:Object, dragonBonesName:String = null):DragonBonesData
		{
			var isComplete:Boolean = true;
			if (rawData is ByteArray)
			{
				const decodeData:DecodedData = DecodedData.decode(rawData as ByteArray);
				if (decodeData)
				{
					_decodeDataList.push(decodeData);
					decodeData.name = dragonBonesName || "";
					decodeData.contentLoaderInfo.addEventListener(Event.COMPLETE, _loadTextureAtlasHandler);
					decodeData.loadBytes(decodeData.textureAtlasBytes, null);
					rawData = decodeData.dragonBonesData;
					isComplete = false;
				}
				else
				{
					return null;
				}
			}
			
			const dragonBonesData:DragonBonesData = ObjectDataParser.getInstance().parseDragonBonesData(rawData);
			addDragonBonesData(dragonBonesData, dragonBonesName);
			
			if (isComplete)
			{
				clearTimeout(_delayID);
				_delayID = setTimeout(this.dispatchEvent, 30, new Event(Event.COMPLETE));
			}
			
			return dragonBonesData;
		}
		
		/**
		 * @language zh_CN
		 * 解析贴图集数据，并将解析后的数据添加到工厂。
		 * @param rawData 需要解析的原始贴图集数据。 (JSON 或 XML 文件)
		 * @param textureAtlas 贴图集。 (BitmapData 或 ATF 或 DisplayObject)
		 * @param name 为解析后的数据提供一个名称，以便可以通过这个名称来访问数据，如果不提供，则使用数据中的名称。 (默认: <code>null</code>)
		 * @param scale 为贴图集设置一个缩放值。 (默认: <code>0</code> 不缩放)
		 * @return 贴图集数据
		 * @see #getTextureAtlasData()
		 * @see #addTextureAtlasData()
		 * @see #removeTextureAtlasData()
		 * @see dragonBones.textures.TextureAtlasData
		 * @version DragonBones 4.5
		 */
		public function parseTextureAtlasData(rawData:Object, textureAtlas:Object, name:String = null, scale:Number = 0, rawScale:Number = 0):TextureAtlasData
		{
			const textureAtlasData:TextureAtlasData = _generateTextureAtlasData(null, null);
			ObjectDataParser.getInstance().parseTextureAtlasData(rawData, textureAtlasData, scale, rawScale);
			
			if (textureAtlas is Bitmap)
			{
				textureAtlas = (textureAtlas as Bitmap).bitmapData;
			}
			else if (textureAtlas is DisplayObject)
			{
				const displayObject:DisplayObject = textureAtlas as DisplayObject;
				textureAtlas = new BitmapData(displayObject.width, displayObject.height, true, 0);
				(textureAtlas as BitmapData).draw(displayObject, null, null, null, null, true);
			}
			
			_generateTextureAtlasData(textureAtlasData, textureAtlas);
			addTextureAtlasData(textureAtlasData, name);
			return textureAtlasData;
		}
		
		/**
		 * @language zh_CN
		 * 获得指定名称的 DragonBonesData。
		 * @param name 指定的名称。
		 * @return DragonBonesData
		 * @see #parseDragonBonesData()
		 * @see #addDragonBonesData()
		 * @see #removeDragonBonesData()
		 * @see dragonBones.objects.DragonBonesData
		 * @version DragonBones 3.0
		 */
		public function getDragonBonesData(name:String):DragonBonesData
		{
			return _dragonBonesDataMap[name] as DragonBonesData;
		}
		
		/**
		 * @language zh_CN
		 * 将 DragonBonesData 添加到工厂。
		 * @param data DragonBonesData。
		 * @param dragonBonesName 为数据提供一个名称，以便可以通过这个名称来访问数据，如果不提供，则使用数据中的名称。 (默认: <code>null</code>)
		 * @see #parseDragonBonesData()
		 * @see #getDragonBonesData()
		 * @see #removeDragonBonesData()
		 * @see dragonBones.objects.DragonBonesData
		 * @version DragonBones 3.0
		 */
		public function addDragonBonesData(data:DragonBonesData, dragonBonesName:String = null):void
		{
			if (data)
			{
				dragonBonesName = dragonBonesName || data.name;
				if (dragonBonesName)
				{
					if (!_dragonBonesDataMap[dragonBonesName])
					{
						_dragonBonesDataMap[dragonBonesName] = data;
					}
					else
					{
						throw new ArgumentError("Same name data");
					}
				}
				else
				{
					throw new ArgumentError("Unnamed data");
				}
			}
			else
			{
				throw new ArgumentError();
			}
		}
		
		/**
		 * @language zh_CN
		 * 将指定名称的 DragonBonesData 从工厂中移除。
		 * @param dragonBonesName 指定的名称。
		 * @param dispose 是否释放数据。 [<code>false</code>: 开启, <code>true</code>: 不开启] (默认: <code>true</code>)
		 * @see #parseDragonBonesData()
		 * @see #getDragonBonesData()
		 * @see #addDragonBonesData()
		 * @see dragonBones.objects.DragonBonesData
		 * @version DragonBones 3.0
		 */
		public function removeDragonBonesData(dragonBonesName:String, dispose:Boolean = true):void
		{
			const dragonBonesData:DragonBonesData = _dragonBonesDataMap[dragonBonesName];
			if (dragonBonesData)
			{
				if (dispose)
				{
					dragonBonesData.returnToPool();
				}
				
				delete _dragonBonesDataMap[dragonBonesName];
			}
		}
		
		/**
		 * @language zh_CN
		 * 获得指定名称的贴图集数据列表。
		 * @param name 指定的名称。
		 * @return 贴图集数据列表
		 * @see #parseTextureAtlasData()
		 * @see #addTextureAtlasData()
		 * @see #removeTextureAtlasData()
		 * @see dragonBones.textures.TextureAtlasData
		 * @version DragonBones 3.0
		 */
		public function getTextureAtlasData(name:String):Vector.<TextureAtlasData>
		{
			return _textureAtlasDataMap[name] as Vector.<TextureAtlasData>;
		}
		
		/**
		 * @language zh_CN
		 * 将贴图集数据添加到工厂。
		 * @param data 贴图集数据。
		 * @param dragonBonesName 为数据提供一个名称，以便可以通过这个名称来访问数据，如果不提供，则使用数据中的名称。 (默认: <code>null</code>)
		 * @see #parseTextureAtlasData()
		 * @see #getTextureAtlasData()
		 * @see #removeTextureAtlasData()
		 * @see dragonBones.textures.TextureAtlasData
		 * @version DragonBones 3.0
		 */
		public function addTextureAtlasData(data:TextureAtlasData, name:String = null):void
		{
			if (data)
			{
				name = name || data.name;
				if (name)
				{
					const textureAtlasList:Vector.<TextureAtlasData> = _textureAtlasDataMap[name] = _textureAtlasDataMap[name] || new Vector.<TextureAtlasData>;		
					if (textureAtlasList.indexOf(data) < 0)
					{
						textureAtlasList.push(data);
					}
				}
				else
				{
					throw new ArgumentError("Unnamed data");
				}
			}
			else
			{
				throw new ArgumentError();
			}
		}
		
		/**
		 * @language zh_CN
		 * 将指定名称的贴图集数据从工厂中移除。
		 * @param name 指定的名称。
		 * @param dispose 是否释放数据。 [<code>true</code>: 释放, <code>false</code>: 不释放] (默认: <code>true</code>)
		 * @see #parseTextureAtlasData()
		 * @see #getTextureAtlasData()
		 * @see #addTextureAtlasData()
		 * @see dragonBones.textures.TextureAtlasData
		 * @version DragonBones 3.0
		 */
		public function removeTextureAtlasData(name:String, dispose:Boolean = true):void
		{
			const textureAtlasDataList:Vector.<TextureAtlasData> = _textureAtlasDataMap[name] as Vector.<TextureAtlasData>;
			if (textureAtlasDataList)
			{
				if (dispose)
				{
					for each (var textureAtlasData:TextureAtlasData in textureAtlasDataList)
					{
						textureAtlasData.returnToPool();
					}
				}
				
				delete _textureAtlasDataMap[name];
			}
		}
		
		/**
		 * @language zh_CN
		 * 清除所有的数据。
		 * @param disposeData 是否释放骨架和贴图数据。 [<code>true</code>: 释放, <code>false</code>: 不释放] (默认: <code>true</code>)
		 * @see dragonBones.objects.DragonBonesData
		 * @see dragonBones.textures.TextureAtlasData
		 * @version DragonBones 4.5
		 */
		public function clear(disposeData:Boolean = true):void
		{
			var i:String = null;
			
			for (i in _dragonBonesDataMap)
			{
				if (disposeData)
				{
					(_dragonBonesDataMap[i] as DragonBonesData).returnToPool();
				}
				
				delete _dragonBonesDataMap[i];
			}
			
			for (i in _textureAtlasDataMap)
			{
				if (disposeData)
				{
					const textureAtlasDataList:Vector.<TextureAtlasData> = _dragonBonesDataMap[i];
					for each (var textureAtlasData:TextureAtlasData in textureAtlasDataList)
					{
						textureAtlasData.returnToPool();
					}
				}
				
				delete _textureAtlasDataMap[i];
			}
		}
		
		/**
		 * @language zh_CN
		 * 创建一个指定名称的骨架。
		 * @param armatureName 骨架数据名称。
		 * @param dragonBonesName DragonBonesData 名称，如果不提供此名称，将检索所有数据，如果多个数据中包含同名的骨架数据，可能无法创建出准确的骨架。 (默认: <code>null</code>)
		 * @param skinName 皮肤名称。 (默认: <code>null</code>)
		 * @return 创建的骨架
		 * @see dragonBones.Armature
		 * @version DragonBones 4.5
		 */
		public function buildArmature(armatureName:String, dragonBonesName:String = null, skinName:String = null):Armature
		{
			const dataPackage:BuildArmaturePackage = new BuildArmaturePackage();
			if (_fillBuildArmaturePackage(dragonBonesName, armatureName, skinName, dataPackage))
			{
				const armature:Armature = _generateArmature(dataPackage);
				_buildBones(dataPackage, armature);
				_buildSlots(dataPackage, armature);
				
				// Update armature pose
				armature.advanceTime(0);
				return armature;
			}
			
			return null;
		}
		
		/**
		 * @language zh_CN
		 * 将指定骨架的动画替换成其他骨架的动画。 (通常这些骨架应该具有相同的骨架结构)
		 * @param toArmature 指定的骨架。
		 * @param fromArmatreName 其他骨架的名称。
		 * @param fromSkinName 其他骨架的皮肤名称。 (默认: <code>null</code>)
		 * @param fromDragonBonesDataName 其他骨架所在的 DragonBonesData 名称。 (默认: <code>null</code>)
		 * @param ifRemoveOriginalAnimationList 是否移除原有的动画。 [<code>true</code>: 移除, <code>false</code>: 不移除] (默认: <code>true</code>)
		 * @return 是否替换成功  [<code>true</code>: 成功, <code>false</code>: 不成功]
		 * @see dragonBones.Armature
		 * @version DragonBones 4.5
		 */
		public function copyAnimationsToArmature(
			toArmature:Armature, fromArmatreName:String, fromSkinName:String = null, 
			fromDragonBonesDataName:String = null, ifRemoveOriginalAnimationList:Boolean = true
		):Boolean
		{
			const dataPackage:BuildArmaturePackage = new BuildArmaturePackage();
			if (_fillBuildArmaturePackage(fromDragonBonesDataName, fromArmatreName, fromSkinName, dataPackage))
			{
				const fromArmatureData:ArmatureData = dataPackage.armature;
				if (ifRemoveOriginalAnimationList)
				{
					toArmature.animation.animations = fromArmatureData.animations;
				}
				else
				{
					const animations:Object = {};
					var animationName:String = null;
					for (animationName in toArmature.animation.animations)
					{
						animations[animationName] = toArmature.animation.animations[animationName];
					}
					
					for (animationName in fromArmatureData.animations)
					{
						animations[animationName] = fromArmatureData.animations[animationName];
					}
					
					toArmature.animation.animations = animations;
				}
				
				if (dataPackage.skin)
				{
					for each(var toSlot:Slot in toArmature.getSlots())
					{
						const toSlotDisplayList:Vector.<Object> = toSlot.displayList;
						for (var i:uint = 0, l:uint = toSlotDisplayList.length; i < l; ++i)
						{
							const toDisplayObject:Object = toSlotDisplayList[i];
							if (toDisplayObject is Armature)
							{
								const displays:Vector.<DisplayData> = dataPackage.skin.getSlot(toSlot.name).displays;
								if (i < displays.length)
								{
									const fromDisplayData:DisplayData = displays[i];
									if (fromDisplayData.type == DragonBones.DISPLAY_TYPE_ARMATURE)
									{
										copyAnimationsToArmature(toDisplayObject as Armature, fromDisplayData.name, fromSkinName, fromDragonBonesDataName, ifRemoveOriginalAnimationList);
									}
								}
							}
						}
					}
					
					return true;
				}
			}
			
			return false;
		}
		
		/**
		 * @language zh_CN
		 * 将指定插槽的显示对象替换为指定资源创造出的显示对象。
		 * @param dragonBonesName 指定的 DragonBonesData 名称。
		 * @param armatureName 指定的骨架名称。
		 * @param slotName 指定的插槽名称。
		 * @param displayName 指定的显示对象名称。
		 * @param slot 指定的插槽实例。
		 * @param displayIndex 要替换的显示对象的索引，如果未指定索引则替换当前正在显示的显示对象。 (默认: -1)
		 * @version DragonBones 3.0
		 */
		public function replaceSlotDisplay(dragonBonesName:String, armatureName:String, slotName:String, displayName:String, slot:Slot, displayIndex:int = -1):void
		{
			var displayData:DisplayData = null;
			
			const dataPackage:BuildArmaturePackage = new BuildArmaturePackage();
			if (_fillBuildArmaturePackage(dragonBonesName, armatureName, null, dataPackage))
			{
				const slotDisplayDataSet:SlotDisplayDataSet = dataPackage.skin.getSlot(slotName);
				if (slotDisplayDataSet)
				{
					for each (displayData in slotDisplayDataSet.displays)
					{
						if (displayData.name == displayName)
						{
							break;
						}
						
						displayData = null;
					}
				}
			}
			
			_replaceSlotDisplay(dataPackage, displayData, slot, displayIndex);
		}
		
		/**
		 * @language zh_CN
		 * 将指定插槽的显示对象列表替换为指定资源创造出的显示对象列表。
		 * @param dragonBonesName 指定的 DragonBonesData 名称。
		 * @param armatureName 指定的骨架名称。
		 * @param slotName 指定的插槽名称。
		 * @param slot 指定的插槽实例。
		 * @version DragonBones 3.0
		 */
		public function replaceSlotDisplayList(dragonBonesName:String, armatureName:String, slotName:String, slot:Slot):void
		{
			const dataPackage:BuildArmaturePackage = new BuildArmaturePackage();
			if (!_fillBuildArmaturePackage(dragonBonesName, armatureName, null, dataPackage))
			{
				return;
			}
			
			const slotDisplayDataSet:SlotDisplayDataSet = dataPackage.skin.getSlot(slotName);
			if (!slotDisplayDataSet)
			{
				return;
			}
			
			var displayIndex:uint = 0;
			for each (var displayData:DisplayData in slotDisplayDataSet.displays)
			{
				_replaceSlotDisplay(dataPackage, displayData, slot, displayIndex++);
			}
		}
		
		/**
		 * @language zh_CN
		 * 不推荐使用的API。
		 * @see #clear();
		 * @version DragonBones 3.0
		 */
		public function dispose():void
		{
			clear();
		}
	}
}