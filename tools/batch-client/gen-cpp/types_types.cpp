/**
 * Autogenerated by Thrift Compiler (0.9.0)
 *
 * DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
 *  @generated
 */
#include "types_types.h"

#include <algorithm>



int _kTypeTypeValues[] = {
  TypeType::Undefined,
  TypeType::Package,
  TypeType::Function,
  TypeType::Class,
  TypeType::Interface,
  TypeType::Named,
  TypeType::TypeVariable,
  TypeType::Tuple,
  TypeType::List
};
const char* _kTypeTypeNames[] = {
  "Undefined",
  "Package",
  "Function",
  "Class",
  "Interface",
  "Named",
  "TypeVariable",
  "Tuple",
  "List"
};
const std::map<int, const char*> _TypeType_VALUES_TO_NAMES(::apache::thrift::TEnumIterator(9, _kTypeTypeValues, _kTypeTypeNames), ::apache::thrift::TEnumIterator(-1, NULL, NULL));

const char* TypeProto::ascii_fingerprint = "8AE658BECF35742FA6D2BF892CC73B6F";
const uint8_t TypeProto::binary_fingerprint[16] = {0x8A,0xE6,0x58,0xBE,0xCF,0x35,0x74,0x2F,0xA6,0xD2,0xBF,0x89,0x2C,0xC7,0x3B,0x6F};

uint32_t TypeProto::read(::apache::thrift::protocol::TProtocol* iprot) {

  uint32_t xfer = 0;
  std::string fname;
  ::apache::thrift::protocol::TType ftype;
  int16_t fid;

  xfer += iprot->readStructBegin(fname);

  using ::apache::thrift::protocol::TProtocolException;

  bool isset_cls = false;

  while (true)
  {
    xfer += iprot->readFieldBegin(fname, ftype, fid);
    if (ftype == ::apache::thrift::protocol::T_STOP) {
      break;
    }
    switch (fid)
    {
      case 1:
        if (ftype == ::apache::thrift::protocol::T_I32) {
          int32_t ecast0;
          xfer += iprot->readI32(ecast0);
          this->cls = (TypeType::type)ecast0;
          isset_cls = true;
        } else {
          xfer += iprot->skip(ftype);
        }
        break;
      case 2:
        if (ftype == ::apache::thrift::protocol::T_STRING) {
          xfer += iprot->readString(this->name);
          this->__isset.name = true;
        } else {
          xfer += iprot->skip(ftype);
        }
        break;
      case 3:
        if (ftype == ::apache::thrift::protocol::T_LIST) {
          {
            this->items.clear();
            uint32_t _size1;
            ::apache::thrift::protocol::TType _etype4;
            xfer += iprot->readListBegin(_etype4, _size1);
            this->items.resize(_size1);
            uint32_t _i5;
            for (_i5 = 0; _i5 < _size1; ++_i5)
            {
              xfer += iprot->readI32(this->items[_i5]);
            }
            xfer += iprot->readListEnd();
          }
          this->__isset.items = true;
        } else {
          xfer += iprot->skip(ftype);
        }
        break;
      case 4:
        if (ftype == ::apache::thrift::protocol::T_LIST) {
          {
            this->params.clear();
            uint32_t _size6;
            ::apache::thrift::protocol::TType _etype9;
            xfer += iprot->readListBegin(_etype9, _size6);
            this->params.resize(_size6);
            uint32_t _i10;
            for (_i10 = 0; _i10 < _size6; ++_i10)
            {
              xfer += iprot->readI32(this->params[_i10]);
            }
            xfer += iprot->readListEnd();
          }
          this->__isset.params = true;
        } else {
          xfer += iprot->skip(ftype);
        }
        break;
      case 5:
        if (ftype == ::apache::thrift::protocol::T_LIST) {
          {
            this->inputs.clear();
            uint32_t _size11;
            ::apache::thrift::protocol::TType _etype14;
            xfer += iprot->readListBegin(_etype14, _size11);
            this->inputs.resize(_size11);
            uint32_t _i15;
            for (_i15 = 0; _i15 < _size11; ++_i15)
            {
              xfer += iprot->readI32(this->inputs[_i15]);
            }
            xfer += iprot->readListEnd();
          }
          this->__isset.inputs = true;
        } else {
          xfer += iprot->skip(ftype);
        }
        break;
      case 6:
        if (ftype == ::apache::thrift::protocol::T_LIST) {
          {
            this->outputs.clear();
            uint32_t _size16;
            ::apache::thrift::protocol::TType _etype19;
            xfer += iprot->readListBegin(_etype19, _size16);
            this->outputs.resize(_size16);
            uint32_t _i20;
            for (_i20 = 0; _i20 < _size16; ++_i20)
            {
              xfer += iprot->readI32(this->outputs[_i20]);
            }
            xfer += iprot->readListEnd();
          }
          this->__isset.outputs = true;
        } else {
          xfer += iprot->skip(ftype);
        }
        break;
      case 7:
        if (ftype == ::apache::thrift::protocol::T_I32) {
          xfer += iprot->readI32(this->type);
          this->__isset.type = true;
        } else {
          xfer += iprot->skip(ftype);
        }
        break;
      default:
        xfer += iprot->skip(ftype);
        break;
    }
    xfer += iprot->readFieldEnd();
  }

  xfer += iprot->readStructEnd();

  if (!isset_cls)
    throw TProtocolException(TProtocolException::INVALID_DATA);
  return xfer;
}

uint32_t TypeProto::write(::apache::thrift::protocol::TProtocol* oprot) const {
  uint32_t xfer = 0;
  xfer += oprot->writeStructBegin("TypeProto");

  xfer += oprot->writeFieldBegin("cls", ::apache::thrift::protocol::T_I32, 1);
  xfer += oprot->writeI32((int32_t)this->cls);
  xfer += oprot->writeFieldEnd();

  if (this->__isset.name) {
    xfer += oprot->writeFieldBegin("name", ::apache::thrift::protocol::T_STRING, 2);
    xfer += oprot->writeString(this->name);
    xfer += oprot->writeFieldEnd();
  }
  if (this->__isset.items) {
    xfer += oprot->writeFieldBegin("items", ::apache::thrift::protocol::T_LIST, 3);
    {
      xfer += oprot->writeListBegin(::apache::thrift::protocol::T_I32, static_cast<uint32_t>(this->items.size()));
      std::vector<int32_t> ::const_iterator _iter21;
      for (_iter21 = this->items.begin(); _iter21 != this->items.end(); ++_iter21)
      {
        xfer += oprot->writeI32((*_iter21));
      }
      xfer += oprot->writeListEnd();
    }
    xfer += oprot->writeFieldEnd();
  }
  if (this->__isset.params) {
    xfer += oprot->writeFieldBegin("params", ::apache::thrift::protocol::T_LIST, 4);
    {
      xfer += oprot->writeListBegin(::apache::thrift::protocol::T_I32, static_cast<uint32_t>(this->params.size()));
      std::vector<int32_t> ::const_iterator _iter22;
      for (_iter22 = this->params.begin(); _iter22 != this->params.end(); ++_iter22)
      {
        xfer += oprot->writeI32((*_iter22));
      }
      xfer += oprot->writeListEnd();
    }
    xfer += oprot->writeFieldEnd();
  }
  if (this->__isset.inputs) {
    xfer += oprot->writeFieldBegin("inputs", ::apache::thrift::protocol::T_LIST, 5);
    {
      xfer += oprot->writeListBegin(::apache::thrift::protocol::T_I32, static_cast<uint32_t>(this->inputs.size()));
      std::vector<int32_t> ::const_iterator _iter23;
      for (_iter23 = this->inputs.begin(); _iter23 != this->inputs.end(); ++_iter23)
      {
        xfer += oprot->writeI32((*_iter23));
      }
      xfer += oprot->writeListEnd();
    }
    xfer += oprot->writeFieldEnd();
  }
  if (this->__isset.outputs) {
    xfer += oprot->writeFieldBegin("outputs", ::apache::thrift::protocol::T_LIST, 6);
    {
      xfer += oprot->writeListBegin(::apache::thrift::protocol::T_I32, static_cast<uint32_t>(this->outputs.size()));
      std::vector<int32_t> ::const_iterator _iter24;
      for (_iter24 = this->outputs.begin(); _iter24 != this->outputs.end(); ++_iter24)
      {
        xfer += oprot->writeI32((*_iter24));
      }
      xfer += oprot->writeListEnd();
    }
    xfer += oprot->writeFieldEnd();
  }
  if (this->__isset.type) {
    xfer += oprot->writeFieldBegin("type", ::apache::thrift::protocol::T_I32, 7);
    xfer += oprot->writeI32(this->type);
    xfer += oprot->writeFieldEnd();
  }
  xfer += oprot->writeFieldStop();
  xfer += oprot->writeStructEnd();
  return xfer;
}

void swap(TypeProto &a, TypeProto &b) {
  using ::std::swap;
  swap(a.cls, b.cls);
  swap(a.name, b.name);
  swap(a.items, b.items);
  swap(a.params, b.params);
  swap(a.inputs, b.inputs);
  swap(a.outputs, b.outputs);
  swap(a.type, b.type);
  swap(a.__isset, b.__isset);
}

const char* Type::ascii_fingerprint = "266812D7B08D83CE59DBDB712EC9B334";
const uint8_t Type::binary_fingerprint[16] = {0x26,0x68,0x12,0xD7,0xB0,0x8D,0x83,0xCE,0x59,0xDB,0xDB,0x71,0x2E,0xC9,0xB3,0x34};

uint32_t Type::read(::apache::thrift::protocol::TProtocol* iprot) {

  uint32_t xfer = 0;
  std::string fname;
  ::apache::thrift::protocol::TType ftype;
  int16_t fid;

  xfer += iprot->readStructBegin(fname);

  using ::apache::thrift::protocol::TProtocolException;


  while (true)
  {
    xfer += iprot->readFieldBegin(fname, ftype, fid);
    if (ftype == ::apache::thrift::protocol::T_STOP) {
      break;
    }
    switch (fid)
    {
      case 1:
        if (ftype == ::apache::thrift::protocol::T_LIST) {
          {
            this->types.clear();
            uint32_t _size25;
            ::apache::thrift::protocol::TType _etype28;
            xfer += iprot->readListBegin(_etype28, _size25);
            this->types.resize(_size25);
            uint32_t _i29;
            for (_i29 = 0; _i29 < _size25; ++_i29)
            {
              xfer += this->types[_i29].read(iprot);
            }
            xfer += iprot->readListEnd();
          }
          this->__isset.types = true;
        } else {
          xfer += iprot->skip(ftype);
        }
        break;
      default:
        xfer += iprot->skip(ftype);
        break;
    }
    xfer += iprot->readFieldEnd();
  }

  xfer += iprot->readStructEnd();

  return xfer;
}

uint32_t Type::write(::apache::thrift::protocol::TProtocol* oprot) const {
  uint32_t xfer = 0;
  xfer += oprot->writeStructBegin("Type");

  if (this->__isset.types) {
    xfer += oprot->writeFieldBegin("types", ::apache::thrift::protocol::T_LIST, 1);
    {
      xfer += oprot->writeListBegin(::apache::thrift::protocol::T_STRUCT, static_cast<uint32_t>(this->types.size()));
      std::vector<TypeProto> ::const_iterator _iter30;
      for (_iter30 = this->types.begin(); _iter30 != this->types.end(); ++_iter30)
      {
        xfer += (*_iter30).write(oprot);
      }
      xfer += oprot->writeListEnd();
    }
    xfer += oprot->writeFieldEnd();
  }
  xfer += oprot->writeFieldStop();
  xfer += oprot->writeStructEnd();
  return xfer;
}

void swap(Type &a, Type &b) {
  using ::std::swap;
  swap(a.types, b.types);
  swap(a.__isset, b.__isset);
}


